// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.util.AttributeSet
import android.util.Log
import android.webkit.JavascriptInterface
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import org.json.JSONObject

class WebView : android.webkit.WebView {
    companion object {
        val TAG = WebView.javaClass.simpleName
    }
    constructor(context: Context?) : super(context) {
        this.defaultSettings(context)
    }
    constructor(
        context: Context?, attrs: AttributeSet?
    ) : super(context, attrs)
    {
        this.defaultSettings(context)
    }

    constructor(
        context: Context?, attrs: AttributeSet?, defStyleAttr: Int
    ) : super(context, attrs, defStyleAttr)
    {
        this.defaultSettings(context)
    }

    constructor(
        context: Context?,
        attrs: AttributeSet?,
        defStyleAttr: Int,
        defStyleRes: Int
    ) : super(context, attrs, defStyleAttr, defStyleRes)
    {
        this.defaultSettings(context)
    }

    var webViewBridge : WebViewBridge? = null
        set(value) {
            val wasNull = (field == null)
            field = value
            if (wasNull) {
                this.addJavascriptInterface(this.bridge, "commandBridge")
            }
        }

    fun sendObject(
        jsonObject: JSONObject,
        resultCallback: ((JSONObject) -> Unit)?
    )
    {
        evaluateJavascript("commandBridge.receiveObject($jsonObject);") {
            resultCallback?.invoke(JSONObject(it))
        }
    }
    fun sendObject(
        map: Map<String, Any>,
        resultCallback: (JSONObject) -> Unit
    ) {
        this.sendObject(JSONObject(map), resultCallback)
    }

    private val bridge = object : Any() {
        @JavascriptInterface
        fun sendString(command: String) : String {
            val jsonObject = JSONObject(command)
            return webViewBridge!!.handleCommand(jsonObject).toString()
        }
    }

    // Native getWebViewClient is API level 26, which is too high. Get around
    // that by implementing a property like a polyfill.
    private val _webViewClient by lazy {
        com.example.captivewebview.WebViewClient()
    }
    private fun defaultSettings(context: Context?) {
        this.settings.javaScriptEnabled = true
        android.webkit.WebView.setWebContentsDebuggingEnabled(true)
        this.webViewClient = this._webViewClient
    }

    var captive:Boolean
        get() {return this._webViewClient.captive }
        set(value) {
            if (!value) {
                // If the web view isn't captive, it might need to access the
                // Internet, so check the application has permission here.

                // Convenience variable for debugger.
                val context = this?.context

                val canInternet: Boolean = context?.run {
                    this.packageManager.checkPermission(
                        Manifest.permission.INTERNET, this.packageName
                    ) == PackageManager.PERMISSION_GRANTED
                } ?: true

                if (!canInternet) {
                    Log.w(TAG,
                        "Possible missing permission android.permission.INTERNET")
                }
            }
            this._webViewClient.captive = value
        }

    fun loadCustomAsset(context: Context,
                        scheme: String = WebViewClient.ASSET_SCHEME,
                        file: String = "index.html") : Uri
    {
        val filePaths = WebResource.findAsset(context, file)
        val builder = Uri.Builder()
        builder.scheme(scheme)
        builder.authority(WebViewClient.ASSET_AUTHORITY)

        // If at least one path was found, then use the first one. Otherwise,
        // use the file name on its own, which will fail later so that an error
        // will be shown in the web view.
        builder.path(if (filePaths.count() > 0) filePaths[0] else file)

        loadUrl(builder.toString())
        return builder.build()
    }

    fun loadCustomAsset(context: Context,
                        file: String = "index.html") : Uri
    {
        return loadCustomAsset(context, WebViewClient.ASSET_SCHEME, file)
    }

}

class WebViewClient : android.webkit.WebViewClient() {
    companion object {
        // Setting the scheme to https seems to make Android WebView do the
        // following.
        //
        // -   Include the authority in the Origin header of the request.
        // -   Recognise the response as having a secure origin, and therefore
        //     making available the window.crypto.subtle object.
        //
        // This code originally used a custom scheme, `local`. Combining that
        // with an authority, `localhost`, that should be recognised as secure
        // didn't seem to work. The request Origin header only included the
        // scheme, not the authority, which may have been why it didn't work.
        const val ASSET_SCHEME = "https"
        const val ASSET_AUTHORITY = "localhost"
        val TAG = WebViewClient.javaClass.simpleName
    }

    var captive = true

    override fun shouldInterceptRequest(
        view: android.webkit.WebView?,
        request: WebResourceRequest?
    ): WebResourceResponse?
    {
        val url = request?.url
        // Next line is useful for diagnostic purposes, like if you want to see
        // the Origin header.
        // val headers = request?.requestHeaders
        val scheme = url?.scheme ?: ""
        val authority = url?.authority ?: ""

        return if (
            scheme.equals(ASSET_SCHEME, true) and
            authority.equals(ASSET_AUTHORITY, true)
        ) {
            com.example.captivewebview.WebResource.assetResponse(
                request!!, view!!.context)
        }
        else if (captive) {
            com.example.captivewebview.WebResource.htmlErrorResponse(403, """
                Resource "$url" with scheme "$scheme" and authority "$authority"
                cannot be loaded. Only "$ASSET_SCHEME" and "$ASSET_AUTHORITY"
                can be loaded.
            """.trimIndent())
        }
        else {
            null
        }
    }
}

interface WebViewBridge {
    fun handleCommand(jsonObject: JSONObject) : JSONObject
}
