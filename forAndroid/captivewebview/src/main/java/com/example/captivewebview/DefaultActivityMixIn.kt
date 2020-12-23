// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.content.Intent
import com.example.captivewebview.ActivityMixIn.Companion.WEB_VIEW_ID
import org.json.JSONArray
import org.json.JSONObject
import java.io.File

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
        private const val CONFIRM_KEY = "confirm"
        private const val COMMAND_KEY = "command"
        const val EXCEPTION_KEY = "failed"
        private const val LOAD_PAGE_KEY = "load"

        // Android Studio warns that these should start with capital letters but
        // they shouldn't because they have to match what gets sent from the JS
        // layer.
        private enum class Command {
            close, focus, load, write, UNKNOWN;

            companion object {
                fun matching(string: String?): Command? {
                    return if (string == null) null
                    else try { valueOf(string) }
                    catch (exception: Exception) { UNKNOWN }
                }
            }
        }

        private enum class KEY {
            text, filename, wrote
        }
        private fun JSONObject.opt(key: KEY): Any? {
            return this.opt(key.name)
        }
        // Enables members of the KEY enumeration to be used as keys in mappings
        // from String to any, for example as mapOf() parameters.
        private infix fun <VALUE> KEY.to(that: VALUE): Pair<String, VALUE> {
            return this.name to that
        }

        val activityMap = mutableMapOf<String, Class<android.app.Activity>>()

        fun addToActivityMap(key:String, activityClassJava: Any) {
            activityMap.put(key, activityClassJava as Class<android.app.Activity>)
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
            val returning = (jsonObject.opt(COMMAND_KEY) as? String)?.let {
                commandResponse(it, jsonObject)
            } ?: jsonObject

            returning.put(CONFIRM_KEY,
                (jsonObject.opt(LOAD_PAGE_KEY) as? String)?.let {
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
            jsonObject.put(EXCEPTION_KEY,
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

            Command.focus -> jsonObject.put("focussed", focusWebView())

            Command.load -> (jsonObject.get("parameters") as JSONObject).let {
                // Scope function `let` returns the result of the lambda and
                // makes the context object available as `it`.
                jsonObject.put("loaded", this.loadActivity(it))
            }

            Command.write ->
                writeFile(jsonObject.get("parameters") as JSONObject)

            null -> jsonObject

            Command.UNKNOWN -> throw Exception("Unknown command \"$command\".")

        }
    }

    private fun loadActivity(parameters: JSONObject): String {
        // parameters.remove("page") //Induce error: No page value.
        // parameters.put("page", "duff_page") // Induce error: No page.
        val page = parameters.opt("page") as? String
            ?: throw Exception("No page specified.")
        val activityClass = activityMap.get(page)
            ?: throw Exception("Page \"$page\" isn't in activityMap.")
        this as Activity
        val intent = Intent(this, activityClass)
        this.startActivity(intent)
        return page
    }

    private fun writeFile(parameters: JSONObject): JSONObject {
        this as Activity
        val file = File(
            filesDir,
            parameters.opt(KEY.filename) as? String
                ?: throw Exception("No file name specified")
        ).absoluteFile
        file.writeText(
            parameters.opt(KEY.text) as? String
            ?: throw Exception("No text specified"))
        return JSONObject(mapOf(KEY.wrote to file.toString()))
    }

}
