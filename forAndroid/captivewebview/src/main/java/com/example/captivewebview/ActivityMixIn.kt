// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.content.Context
import android.content.pm.ActivityInfo
import android.util.Log
import android.view.View
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import org.json.JSONObject

interface ActivityMixIn {
    companion object {
        val WEB_VIEW_ID = View.generateViewId()
        val nameSuffix = "Activity"

        fun onCreateMixIn(activity: android.app.Activity) {
            warnMissingDeclaration(activity)
            com.example.captivewebview.WebView(activity).apply {
                id = WEB_VIEW_ID
                layoutParams = FrameLayout.LayoutParams(
                    FrameLayout.LayoutParams.MATCH_PARENT,
                    FrameLayout.LayoutParams.MATCH_PARENT
                )
            }.let {
                FrameLayout(activity).apply { addView(it) }
            }.also { activity.setContentView(it) }
        }

        private fun warnMissingDeclaration(activity: android.app.Activity) {
            // An Activity based on this Activity should declare that it handles
            // some configuration changes in the Android manifest. If it doesn't,
            // the default handling will apply, which means that the Activity gets
            // destroyed and re-created when, for example, the device orientation is
            // changed. This in turn means that the WebView instance will be
            // destroyed and any data in it lost.
            // Note that it seems unnecessary to implement anything to handle the
            // changes. The WebView does that on its own. So there isn't an
            // onConfigurationChanged() implementation here.
            // It'd be nice to make that happen in the manifest, i.e. declare that
            // handling in the library manifest for this class and have that merged
            // into any subclass by default. However, there doesn't seem to be a way
            // to do that. Second best is to check whether the required configuration
            // change handling is declared and print a warning if not.
            val configInfo = activity.packageManager.getActivityInfo(
                activity.componentName, 0
            ).configChanges
            val missing = mutableListOf<String>()
            if (configInfo and ActivityInfo.CONFIG_ORIENTATION == 0) {
                missing.add("orientation")
            }
            if (configInfo and ActivityInfo.CONFIG_SCREEN_SIZE == 0) {
                missing.add("screenSize")
            }
            if (configInfo and ActivityInfo.CONFIG_KEYBOARD_HIDDEN == 0) {
                missing.add("keyboardHidden")
            }
            if (missing.count() > 0) {
                // Following statement uses `this` in the TAG parameter so that the
                // subclass name appears there.
                Log.w(
                    activity.javaClass.canonicalName,
                    "Missing declaration in manifest <activity>" +
                            " android:configChanges=" +
                            missing.joinToString(
                                prefix = "\"", separator = "|", postfix = "\"."
                            )
                )
            }
        }

    }

    fun android.app.Activity.onCreateMixIn() {
        onCreateMixIn(this)
    }

    val mainHTML: String
        get() {
            return this.javaClass.simpleName.removeSuffix(nameSuffix) + ".html"
        }

    fun  android.app.Activity.onResumeMixIn() {
        val webView =
            findViewById<com.example.captivewebview.WebView>(WEB_VIEW_ID)
        if (webView.url == null) {
            webView.loadCustomAsset(this.applicationContext, mainHTML)
        }
    }
    fun android.app.Activity.focusWebView(): Boolean {
        // https://developer.android.com/training/keyboard-input/visibility#ShowOnDemand
        val view = findViewById<View>(WEB_VIEW_ID)
        val requested = view.requestFocus()
        if (requested) {
            val manager = getSystemService(
                Context.INPUT_METHOD_SERVICE
            ) as InputMethodManager
            manager.showSoftInput(view, InputMethodManager.SHOW_IMPLICIT)
        }
        return requested
    }

    fun android.app.Activity.sendObject(
        jsonObject: JSONObject,
        resultCallback: ((JSONObject) -> Unit)?
    ) {
        val webView =
            findViewById<com.example.captivewebview.WebView>(WEB_VIEW_ID)
        runOnUiThread {
            webView.sendObject(jsonObject, resultCallback)
        }
    }
    fun android.app.Activity.sendObject(
        map: Map<String, Any>,
        resultCallback: ((JSONObject) -> Unit)?
    ) {
        this.sendObject(JSONObject(map), resultCallback)
    }

}