// Copyright 2022 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.content.Context
import android.content.Intent
import android.util.Base64
import com.example.captivewebview.ActivityMixIn.Companion.WEB_VIEW_ID
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import org.json.JSONTokener
import java.io.File
import java.io.IOException
import java.net.HttpURLConnection
import java.net.MalformedURLException
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
            , fetched, fetchError, status, statusText, fetchedRaw
            , bytesTransferred, fetchedDetails
            ,

            // Keys used by the `write` command.
            base64decode, text, filename, wrote
        }
        private fun JSONObject.opt(key: KEY): Any? {
            return this.opt(key.name)
        }
        private fun JSONObject.put(key: KEY, value: Any?): JSONObject {
            return this.put(key.name, value)
        }
        private fun JSONObject.putOpt(key: KEY, value: Any?): JSONObject {
            return this.putOpt(key.name, value)
        }

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

        fun builtInFetch(jsonObject: JSONObject): JSONObject {
            var fetchedRaw: String? = null

            fun return_(
                status:Int?, fetched: JSONObject?, details: JSONObject?
            ):JSONObject = JSONObject()
                .put(KEY.fetchedRaw, fetchedRaw ?: JSONObject.NULL)
                .apply {
                    if (fetched == null) {
                        put(KEY.fetchError,
                            (details ?: JSONObject()).putOpt(KEY.status, status)
                        )
                    }
                    else {
                        put(KEY.fetched, fetched)
                        put(KEY.fetchedDetails,
                            (details ?: JSONObject()).putOpt(KEY.status, status)
                        )
                    }
                }

            val url = parseFetchResource(jsonObject).run {
                second?.let { return return_(0, null, it) }
                first as URL }

            val connection = connectForFetch(url).run {
                second?.let { return return_(1, null, it) }
                first as HttpsURLConnection }

            // ToDo
            // https://developer.android.com/reference/javax/net/ssl/HttpsURLConnection#getServerCertificates()

            val details: JSONObject
            requestForFetch(connection, jsonObject).also {
                fetchedRaw = it.first
                details = it.second
            }
            connection.disconnect()

            if ((details.opt(KEY.status) as? Int ?: 0) !in 200..299) {
                return return_(null, null, details)
            }

            parseJSON(fetchedRaw).run {
                second?.let { return return_(2, null, it) }
                return return_(null, first, details)
            }
        }

        private fun parseFetchResource(jsonObject: JSONObject)
        : Pair<URL?, JSONObject?>
        {
            val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                ?: return Pair(null, JSONObject()
                    .put(KEY.statusText,
                        "No parameters in fetch command, or isn't JSONObject."))
            val resource = parameters.opt(KEY.resource) as? String
                ?: return Pair(
                    null, JSONObject()
                        .put(KEY.statusText,
                            "No parameters.resource in fetch command,"
                            + " or isn't String.")
                )
            return try { Pair(URL(resource), null) }
            catch (exception: MalformedURLException) { Pair(null, JSONObject()
                .put(KEY.statusText, exception::class.java.simpleName)
                .put(KEY.headers, JSONObject().put(KEY.resource, resource))
            ) }
        }

        private fun connectForFetch(url: URL)
        : Pair<HttpsURLConnection?, JSONObject?>
        {
            val connection = try { url.openConnection() as HttpsURLConnection }
            catch (exception: IOException) {
                return Pair(null, JSONObject()
                    .put(KEY.statusText, exception.localizedMessage)
                )
            }

            return try {
                connection.connect()
                Pair(connection, null)
            }
            catch (exception: SocketTimeoutException) { Pair(null, JSONObject()
                .put(KEY.statusText, exception::class.java.simpleName)
                .put(KEY.headers, JSONObject()
                    .put(KEY.statusText, exception.localizedMessage)
                    .put(KEY.bytesTransferred, exception.bytesTransferred))) }
            catch (exception: IOException) { Pair(null, JSONObject()
                .put(KEY.statusText, exception::class.java.simpleName)
                .put(KEY.headers, JSONObject()
                    .put(KEY.statusText, exception.localizedMessage))) }
            catch (exception: SecurityException) { Pair(null, JSONObject()
                .put(KEY.statusText, exception::class.java.simpleName)
                .put(KEY.headers, JSONObject()
                    .put(KEY.statusText, exception.localizedMessage))) }
        }

        private fun requestForFetch(
            connection: HttpsURLConnection, jsonObject: JSONObject
        ): Pair<String?, JSONObject>
        {
            val details = JSONObject()
                .put(KEY.status, connection.responseCode)
                .put(KEY.statusText, connection.responseMessage)
                .put(KEY.headers, headers(connection))


            val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                ?: JSONObject()
            val options = parameters.opt(KEY.options) as? JSONObject
                ?: JSONObject()

            var body:String? = null
            (options.opt(KEY.method) as? String)?.let {
                connection.requestMethod = it }
            (options.opt(KEY.body) as? String)?.let {
                // Assume JSON but already as a String somehow.
                connection.setRequestProperty(
                    "Content-Type", "application/json")
                body = it + "\r\n\r\n" }
            (options.opt(KEY.bodyObject) as? JSONObject)?.let {
                connection.setRequestProperty(
                    "Content-Type", "application/json")
                body = it.toString() + "\r\n\r\n" }
            (options.opt(KEY.headers) as? JSONObject)?.apply {
                keys().forEach {
                    connection.setRequestProperty(it, get(it) as String) } }

            return try {
                body?.let {
                    connection.doOutput = true
                    connection.outputStream.write(it.encodeToByteArray())
                }

                // ToDo add a maximum size parameter to prevent buffer overrun.

                // Reading from the inputStream throws in the 404 case, for
                // example.
                val stream = if (connection.responseCode in 200..299)
                    connection.inputStream else connection.errorStream

                Pair(
                    generateSequence {
                        stream.read().takeUnless { it == -1 }?.toByte()
                    }.toList().run {
                        ByteArray(size) { index -> get(index) }
                    }.decodeToString(), details)
            }
            catch (exception:Exception) { Pair(null, JSONObject()
                .put(KEY.statusText, exception::class.java.simpleName)
                .put(KEY.headers, JSONObject()
                    .put(KEY.statusText, exception.localizedMessage))) }
        }

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

        private fun parseJSON(raw:String?):Pair<JSONObject?, JSONObject?> {
            return try {
                val tokener = JSONTokener(raw ?: "")
                when (val parsed = tokener.nextValue()) {
                    is JSONObject -> Pair(parsed, null)
                    else -> throw tokener.syntaxError(
                        "Expected JSONObject but found"
                        + " ${parsed::class.java.simpleName}")
                }
            }
            catch (exception: JSONException) {
                Pair(null, JSONObject()
                    .put(KEY.statusText, exception.localizedMessage))
            }
        }

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

            Command.fetch -> builtInFetch(jsonObject)

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
