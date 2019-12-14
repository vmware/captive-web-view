// Copyright 2019 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.headless

import android.app.Activity
import android.os.Bundle
import android.util.Log
import android.view.View
//import android.widget.FrameLayout
import android.widget.TextView
import com.example.captivewebview.DefaultActivityMixIn
import com.example.captivewebview.WebViewBridge
//import com.example.captivewebview.WebViewClient
import org.json.JSONObject
import java.lang.Exception

class MainActivity : Activity(), WebViewBridge {
    companion object {
//        val WEB_VIEW_ID = View.generateViewId()
        val TAG = MainActivity.javaClass.simpleName
    }

    private var token:String? = null
    private var numericParameter = 1

    val webView by lazy {
        com.example.captivewebview.WebView(this).also {
            it.webViewBridge = this
            it.captive = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        // If you want to diagnose problems in the JS then uncomment:
        //
        // -   The FrameLayout in the layout xml.
        // -   The code that adds the WebView to it here.
        //
        // Then the web view will appear in the application user interface.
        //
        // val frame = findViewById<FrameLayout>(R.id.smallFrame)
        // frame.addView(webView)
    }

    override fun onResume() {
        super.onResume()
        if (webView.url == null) {
            webView.loadCustomAsset(this.applicationContext, "Headless.html")
        }
    }

    override fun handleCommand(jsonObject: JSONObject): JSONObject {
        // Next line uses opt() not optString(). That's because optString
        // returns "" if there's no mapping; opt() returns null which is
        // easier to detect.

        return try {
            jsonObject.also {
                it.opt("token")?.also {
                    (it as? String)?.also { this.token = it }
                        ?: throw Exception("Token isn't String:$it.")
                }
                    ?: showResult(it)
            }
        } catch(exception: Exception) {
            findViewById<TextView>(R.id.labelResults).text = "$exception"
            Log.e(TAG, "$exception")
            // Following line returns the exception to the web view, but since
            // it's headless it goes nowhere.
            jsonObject.put(DefaultActivityMixIn.EXCEPTION_KEY, "$exception")
        }
    }

    private fun showResult(jsonObject: JSONObject) {
        val textView = findViewById<TextView>(R.id.labelResults)
        textView.text = jsonObject.toString(4)
    }

    fun buttonSWAPIClicked(view: View) {
        val textView = findViewById<TextView>(R.id.labelResults)
        textView.text = "Sending\nSWAPI"
        webView.sendObject(mapOf(
            "api" to "star-wars",
            "path" to listOf("planets", "$numericParameter")
        ), this::showResult)
        numericParameter += 1
        return
    }

    fun buttonGoRest401Clicked(view: View) {
        val textView = findViewById<TextView>(R.id.labelResults)
        textView.text = "Sending\ngo-rest 401"
        webView.sendObject(
            mapOf(
                "api" to "go-rest",
                "path" to listOf("users", "${numericParameter + 18}")
            ), this::showResult
        )
        return
    }

    fun buttonGoRestQueryParameterClicked(view: View) {
        val textView = findViewById<TextView>(R.id.labelResults)
        textView.text = "Sending\ngo-rest query parameter"
        webView.sendObject(
            mapOf(
                "api" to "go-rest",
                "path" to listOf("users", "${numericParameter + 18}"),
                "query-parameter" to "access-token",
                "token" to (token ?: "No token")
            ), this::showResult
        )
        numericParameter += 1
        return
    }

    fun buttonGoRestBasicClicked(view: View) {
        val textView = findViewById<TextView>(R.id.labelResults)
        textView.text = "Sending\ngo-rest basic"
        webView.sendObject(
            mapOf(
                "api" to "go-rest",
                "path" to listOf("users", "${numericParameter + 18}"),
                "basic-auth" to "Bearer",
                "token" to (token ?: "No token")
            ), this::showResult
        )
        numericParameter += 1
        return
    }
}
