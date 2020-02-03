// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.Manifest
import android.content.pm.PackageManager
import android.support.v4.app.ActivityCompat
import android.util.Log
import android.webkit.PermissionRequest

class WebChromeClient(val webView: WebView): android.webkit.WebChromeClient() {
    companion object {
        private val TAG = WebChromeClient::class.java.simpleName
    }

    override fun onPermissionRequest(request: PermissionRequest) {
        val cameraRequested = request.resources.contains(
            PermissionRequest.RESOURCE_VIDEO_CAPTURE)
        val othersRequested = (!cameraRequested) || (request.resources.size != 1)
        if (cameraRequested) {
            val context = this.webView.context
            val wants = arrayOf(Manifest.permission.CAMERA)

            val hasAppPermission = context.packageManager.checkPermission(
                wants[0], context.packageName
            ) == PackageManager.PERMISSION_GRANTED

            if (hasAppPermission) {
                request.grant(arrayOf((PermissionRequest.RESOURCE_VIDEO_CAPTURE)))
            } else {
                request.deny()
                if (context is Activity) {
                    // Following is API level 23 which is too high for the library.
                    // context.requestPermissions()

                    // Assume the web page makes it obvious why camera permission is being
                    // requested.
                    //
                    // Calling shouldShow... seems to reset an internal flag, and hence force
                    // Android to request the permission again.
                    if (
                        ActivityCompat.shouldShowRequestPermissionRationale(
                            context, wants[0])
                    ) {
                        ActivityCompat.requestPermissions(context, wants, 0)
                    }
                    else {
                        ActivityCompat.requestPermissions(context, wants, 1)
                    }

                    Log.w(
                        TAG,
                        "Possible missing permission android.permission.CAMERA"
                    )
                } else {
                    Log.w(
                        TAG,
                        "Permissions requested from non-Activity: ${context}."
                    )
                }
            }
        }

        if (othersRequested) {
            Log.w(TAG, "Permissions other than camera requested." +
                    " List:${request.resources} Camera:$cameraRequested.")
        }
    }

}
