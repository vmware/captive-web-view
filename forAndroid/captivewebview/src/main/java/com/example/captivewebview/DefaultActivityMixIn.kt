// Copyright 2022 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.content.Context
import android.content.Intent
import android.util.Base64
import com.example.captivewebview.ActivityMixIn.Companion.WEB_VIEW_ID
import org.json.JSONArray
import org.json.JSONObject
import org.json.JSONTokener
import java.io.File
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.URL
import javax.net.ssl.HttpsURLConnection

class CauseIterator(private var throwable: Throwable?): Iterator<Throwable> {
    override fun hasNext(): Boolean {
        return throwable != null
    }

    override fun next(): Throwable {
        return throwable!!.also { throwable = throwable?.cause }
    }
}

/**
 * This MixIn can be used in an application whose Activity subclasses cannot be
 * based on the DefaultActivity class for some reason. Usage is like this.
 *
 *     class MainActivity :
 *         WhateverBaseActivity(), // Or just vanilla Activity()
 *         com.example.captivewebview.DefaultActivityMixIn
 *     {
 *         override fun onCreate(savedInstanceState: Bundle?) {
 *             super.onCreate(savedInstanceState)
 *             onCreateMixIn()
 *         }
 *         override fun onResume() {
 *             super.onResume()
 *             onResumeMixIn()
 *         }
 *     }
 */
interface DefaultActivityMixIn : ActivityMixIn, WebViewBridge {
    companion object {
        // Android Studio warns that these should start with capital letters but
        // they shouldn't because they have to match what gets sent from the JS
        // layer.
        private enum class Command {
            close, fetch, focus, load, write, UNKNOWN;

            companion object {
                fun matching(string: String?): Command? {
                    return if (string == null) null
                    else try { valueOf(string) }
                    catch (exception: Exception) { UNKNOWN }
                }
            }
        }

        enum class KEY {
            // Common keys.
            command, confirm, failed, load, parameters,

            // Keys used by the `fetch` command.
            resource, options, method, body, bodyObject, headers
            , status, statusText, message, json, ok,

            // Keys used by the `write` command.
            base64decode, text, filename, wrote
        }
        private fun JSONObject.opt(key: KEY) = this.opt(key.name)
        private fun JSONObject.put(key: KEY, value: Any?) =
            this.put(key.name, value)
        private fun JSONObject.putOpt(key: KEY, value: Any?) =
            this.putOpt(key.name, value)

        // Enables members of the KEY enumeration to be used as keys in mappings
        // from String to any, for example as mapOf() parameters.
        private infix fun <VALUE> KEY.to(that: VALUE): Pair<String, VALUE> {
            return this.name to that
        }

        val activityMap = mutableMapOf<String, Class<android.app.Activity>>()

        fun addToActivityMap(key:String, activityClassJava: Any) {
            activityMap[key] = activityClassJava as? Class<android.app.Activity>
                ?: throw Exception(
                    "activityClassJava $activityClassJava cannot be cast to"
                    + " Class<android.app.Activity>"
                )
        }
        fun addToActivityMap(map: Map<String, Any>) {
            map.forEach { addToActivityMap(it.key, it.value) }
        }
        fun addToActivityMap(vararg pairs: Pair<String, Any>) {
            pairs.forEach { addToActivityMap(it.first, it.second) }
        }

        fun onCreateMixIn(
            activity: android.app.Activity, loadVisibilityTimeOutSeconds:Float?
        ) {
            ActivityMixIn.onCreateMixIn(activity, loadVisibilityTimeOutSeconds)
            val webView = activity
                .findViewById<com.example.captivewebview.WebView>(WEB_VIEW_ID)
            webView.webViewBridge = activity as WebViewBridge
        }

        enum class FETCH_KEY {
            keys, resource, bytesTransferred, type, value
        }
        private fun JSONObject.put(key: FETCH_KEY, value: Any?) =
            put(key.name, value)
        private fun JSONObject.putOpt(key: FETCH_KEY, value: Any?) =
            putOpt(key.name, value)

        // Android Kotlin has many Exception subclasses but they don't seem to
        // have properties for details. So a custom Exception is used that has a
        // JSONObject for storing properties.
        // In case an error is encountered by one of the component functions of
        // builtInFetch they can throw an instance of the custom Exception and
        // add details to it. If the error is from an Exception thrown by
        // something that the component function called, that exception gets set
        // as the cause of the custom Exception.
        //
        // TOTH custom Exception: https://stackoverflow.com/a/68775013/7657675
        class FetchException(
            message: String? = null, cause: Throwable? = null
        ) : Exception(message, cause) {
            private val details = JSONObject()

            constructor(cause: Throwable) : this(null, cause)

            init {
                details.putOpt(KEY.message, cause?.localizedMessage)
                .putOpt(
                    FETCH_KEY.bytesTransferred,
                    (cause as? SocketTimeoutException)?.bytesTransferred
                )
            }

            fun put(vararg pairs: Pair<FETCH_KEY, Any?>) =
                pairs.forEach {
                    details.put(it.first, it.second ?: JSONObject.NULL)
                }.let { this }

            fun toJSON(status: Int?):JSONObject = JSONObject()
                .put(KEY.ok, false)
                .putOpt(KEY.status, status)
                .putOpt(KEY.statusText,
                    message ?: cause?.let { it::class.java.simpleName }
                )
                .putOpt(KEY.headers, details)
                .put(KEY.text, JSONObject.NULL)
                .put(KEY.json, JSONObject.NULL)
        }

        fun builtInFetch(jsonObject: JSONObject) = builtInFetch(jsonObject) {}

        fun builtInFetch(
            jsonObject: JSONObject, cause: (throwable: Throwable) -> Unit
        ): JSONObject
        {
            val (url, options) = try { parseFetchParameters(jsonObject) }
            catch (exception: FetchException) {
                exception.cause?.let { cause(it) }
                return exception.toJSON(0) }

            val connection = try { prepareConnection(url, options) }
            catch (exception: FetchException) {
                exception.cause?.let { cause(it) }
                return exception.toJSON(1) }

            // ToDo
            // https://developer.android.com/reference/javax/net/ssl/HttpsURLConnection#getServerCertificates()

            val (fetchedRaw, details) = requestForFetch(connection, options)

            connection.disconnect()

            // -   If the HTTP request was OK but the JSON parsing failed,
            //     return the JSON exception.
            // -   If the HTTP request wasn't OK but the JSON parsing succeeded,
            //     the parsed object will be included in the details.
            details.put(KEY.text, fetchedRaw)
            val jsonException:FetchException? = try {
                details.put(KEY.json, parseJSON(fetchedRaw))
                null
            }
            catch (exception: FetchException) {
                exception.cause?.let { cause(it) }
                details.put(KEY.json, JSONObject.NULL)
                exception
            }

            return if (details.getBoolean(KEY.ok.name))
                jsonException?.toJSON(2)?.put(KEY.text, fetchedRaw)
                // ToDo: Add the details before the toJSON() but remove the
                // KEY.text and KEY.json before the exception is used.
                    ?: details
            else details
        }

        private fun parseFetchParameters(jsonObject: JSONObject)
        : Pair<URL, JSONObject>
        {
            val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                ?: throw FetchException(
                    "Fetch command had no `parameters` key, or its value"
                            + " isn't type JSONObject."
                ).put(
                    FETCH_KEY.keys to (jsonObject.names() ?: JSONArray()),
                    FETCH_KEY.type to jsonObject.opt(KEY.parameters)?.let {
                        it::class.java.simpleName }
                )

            val resource = parameters.opt(KEY.resource) as? String
                ?: throw FetchException(
                    "Fetch command parameters had no `resource` key, or its"
                            + " value isn't type String."
                ).put(
                    FETCH_KEY.keys to (parameters.names() ?: JSONArray()),
                    FETCH_KEY.type to parameters.opt(KEY.resource)?.let {
                        it::class.java.simpleName }
                )

            return try { Pair(
                URL(resource),
                parameters.opt(KEY.options) as? JSONObject ?: JSONObject()
            ) }
            catch (exception: Exception) { throw FetchException(exception)
                .put(FETCH_KEY.resource to resource) }
        }

        private fun prepareConnection(url: URL, options: JSONObject) = try {
            (url.openConnection() as HttpsURLConnection).apply {
                // ToDo: Check for known options with wrong type.
                (options.opt(KEY.method) as? String)?.let { requestMethod = it }
                (options.opt(KEY.body) as? String)?.let {
                    // Assume JSON but already as a String somehow.
                    setRequestProperty("Content-Type", "application/json")
                    doOutput = true
                }
                (options.opt(KEY.bodyObject) as? JSONObject)?.let {
                    setRequestProperty("Content-Type", "application/json")
                    doOutput = true
                }
                (options.opt(KEY.headers) as? JSONObject)?.apply {
                    keys().forEach {
                        setRequestProperty(it, get(it) as String) } }
                connect()
            } }
        catch (exception: Exception) { throw FetchException(exception)
            .put(FETCH_KEY.resource to url.toString()) }

        private fun requestForFetch(
            connection: HttpsURLConnection, options: JSONObject
        ) = try {
            // ToDo: Check for known options with wrong type.
            val body =
                (options.opt(KEY.body) as? String)?.let { it + "\r\n\r\n" } ?:
                (options.opt(KEY.bodyObject) as? JSONObject)?.let {
                    it.toString() + "\r\n\r\n" }

            body?.let { connection.outputStream.write(it.encodeToByteArray()) }

            val httpReturn = JSONObject()
                .put(KEY.ok, connection.responseCode in 200..299)
                .put(KEY.status, connection.responseCode)
                .put(KEY.statusText, connection.responseMessage)
                .put(KEY.headers, headers(connection))

            // ToDo add a maximum size parameter to prevent buffer overrun.

            // Reading from the inputStream throws in the 404 case, for example.
            val stream = if (connection.responseCode in 200..299)
                connection.inputStream else connection.errorStream

            Pair(
                generateSequence {
                    stream.read().takeUnless { it == -1 }?.toByte()
                }.toList().run {
                    ByteArray(size) { index -> get(index) }
                }.decodeToString(), httpReturn)
        }
        catch (exception: Exception) { throw FetchException(exception) }

        private fun headers(connection: HttpURLConnection):JSONObject {
            val headers = JSONObject()
            // Generate a sequence of Pair(Int, String) in which
            // -   If Int is zero, String is empty.
            // -   Otherwise String is the header field key with index Int - 1.
            generateSequence(Pair(0, "")) { it.first.let { index ->
                connection.getHeaderFieldKey(index)?.run { Pair(index+1, this) }
            } }.forEach { if (it.first > 0) it.second.let { key ->
                headers.put(key, connection.getHeaderField(key))
            } }
            return headers
        }

        private fun parseJSON(raw:String):Any = JSONTokener(raw).run {
            try { nextValue() }
            catch (exception: Exception) {
                throw FetchException(exception)
            }.also {
                if (it !is JSONObject && it !is JSONArray) throw
                FetchException(syntaxError(
                    "Expected JSONObject or JSONArray but found"
                            + " ${it::class.java.simpleName}"
                )).put(
                    FETCH_KEY.type to it::class.java.simpleName,
                    FETCH_KEY.value to it )
            } }

        fun builtInWrite(context: Context, jsonObject: JSONObject): JSONObject {
            val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                ?: throw Exception("No parameters in write command")
            val asciiToBinary = parameters.opt(KEY.base64decode) as? Boolean
                ?: false
            val text = parameters.opt(KEY.text) as? String
                ?: throw Exception("No text parameter in write command")
            val file = File(
                context.filesDir,
                parameters.opt(KEY.filename) as? String
                    ?: throw Exception(
                        "No file name parameter in write command")
            ).absoluteFile
            if (asciiToBinary) {
                file.writeBytes(Base64.decode(text, Base64.DEFAULT))
            }
            else {
                file.writeText(text)
            }
            return JSONObject(mapOf(KEY.wrote to file.toString()))
        }
    }

    // The following seems like the right way to do this:
    //
    //     fun <T> T.onCreateMixIn()
    //             where T:android.app.Activity, T:WebViewBridge
    //     {
    //         Companion.onCreateMixIn(this)
    //     }
    //
    // It doesn't get through the compiler maybe because it's a selective
    // override of the onCreateMixIn in the ActivityMixIn interface of which
    // this interface is a subclass.

    override fun android.app.Activity.onCreateMixIn() {
        // Call the onCreateMixIn in the Companion to this class.
        onCreateMixIn(this, loadVisibilityTimeOutSeconds)
    }

    // Note for later: The JS layer loads a new HTML page in the same Activity
    // by sending an object like this:
    //
    //     {"load": "page_to_load.html"}
    //
    // To load a new Activity, send a command like the following instead:
    //
    //     {"command": "load", "parameters": {"page": "PageSpecification"}}
    //
    // The PageSpecification string must be in the activityMap in the companion
    // object already.

    override fun handleCommand(jsonObject: JSONObject): JSONObject {
        // This method is a single return statement. Note that Kotlin try
        // returns a value, and the JSONObject put method returns the JSON
        // object instance.
        return try {
            // Next line uses opt() not optString(). That's because optString
            // returns "" if there's no mapping; opt() returns null which is
            // easier to detect.
            val returning = (jsonObject.opt(KEY.command) as? String)?.let {
                commandResponse(it, jsonObject)
            } ?: jsonObject

            returning.put(KEY.confirm,
                (jsonObject.opt(KEY.load) as? String)?.let {
                    // Next line declares that `this` must be an Activity.
                    this as Activity
                    val webView =
                        findViewById<com.example.captivewebview.WebView>(
                            WEB_VIEW_ID)
                    runOnUiThread {
                        webView.loadCustomAsset(applicationContext, it)
                    }
                    "UI thread \"$it\"."
                } ?:
                "${this.javaClass.simpleName} bridge OK."
            )
        } catch(exception: Exception) {
            val exceptions = JSONArray(CauseIterator(exception)
                .asSequence().map { it.toString() }.toList())
            jsonObject.put(KEY.failed,
                if (exceptions.length() == 1) exceptions[0] else exceptions)
        }
    }

    fun commandResponse(command: String?, jsonObject: JSONObject)
            : JSONObject
    {
        this as com.example.captivewebview.Activity
        return when (Command.matching(command)) {

            Command.close -> jsonObject.put("closed", true).also {
                this.finish()
            }

            Command.fetch -> builtInFetch(jsonObject) {
                // Placeholder for logging or taking some other action with the
                // cause of an exception. The exception itself will have been
                // rendered into JSON and returned to the JS layer.
                val throwable = it
            }

            Command.focus -> jsonObject.put("focussed", focusWebView())

            Command.load -> (jsonObject.opt(KEY.parameters) as JSONObject).let {
                // Scope function `let` returns the result of the lambda and
                // makes the context object available as `it`.
                jsonObject.put("loaded", this.loadActivity(it))
            }

            Command.write -> builtInWrite(this as Context, jsonObject)

            null -> jsonObject

            Command.UNKNOWN -> throw Exception("Unknown command \"$command\".")
        }
    }

    private fun loadActivity(parameters: JSONObject): String {
        // parameters.remove("page") //Induce error: No page value.
        // parameters.put("page", "duff_page") // Induce error: No page.
        val page = parameters.opt("page") as? String
            ?: throw Exception("No page specified.")
        val activityClass = activityMap[page]
            ?: throw Exception("Page \"$page\" isn't in activityMap.")
        this as Activity
        val intent = Intent(this, activityClass)
        this.startActivity(intent)
        return page
    }

}
