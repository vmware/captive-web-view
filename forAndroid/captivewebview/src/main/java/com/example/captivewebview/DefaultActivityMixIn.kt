// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.content.Intent
import com.example.captivewebview.ActivityMixIn.Companion.WEB_VIEW_ID
import org.json.JSONObject
import java.lang.Exception

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

        private const val FOCUS_COMMAND = "focus"
        private const val LOAD_COMMAND = LOAD_PAGE_KEY
        private const val CLOSE_COMMAND = "close"

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
        // The following seems like it should be the safe way to declare this
        // method.
        // fun <T> onCreateMixIn(activity: T) where T: Activity, T: WebViewBridge
        // See the comments by
        fun onCreateMixIn(activity: android.app.Activity) {
            ActivityMixIn.onCreateMixIn(activity)
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
        onCreateMixIn(this)
        // Don't load the local asset here. That happens in the onResume() in
        // the base Activity class.
    }

    // Note for later: The demonstrationapplication JS loads a new HTML page in
    // the same Activity by sending an object like this:
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
            jsonObject.put(EXCEPTION_KEY, "$exception")
        }
    }

    fun commandResponse(command: String?, jsonObject: JSONObject)
            : JSONObject
    {
        this as com.example.captivewebview.Activity
        return when (command) {
            CLOSE_COMMAND -> jsonObject.put("closed", true).also { this.finish() }

            FOCUS_COMMAND -> jsonObject.put("focussed", focusWebView())

            LOAD_COMMAND -> (jsonObject.get("parameters") as JSONObject).let {
                // Scope function `let` returns the result of the lambda and
                // makes the context object available as `it`.
                jsonObject.put("loaded", this.loadActivity(it))
            }

            null -> jsonObject

            else -> throw Exception("Unknown command \"$command\".")
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

}