// Copyright 2019 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivity

import android.os.Bundle
import org.json.JSONObject

class MainActivity: com.example.captivewebview.DefaultActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        addToActivityMap("Secondary" to SecondaryActivity::class.java)
    }

    override fun commandResponse(
        command: String?,
        jsonObject: JSONObject
    ): JSONObject {
        return when(command) {
            "ready" -> jsonObject
            else -> super.commandResponse(command, jsonObject)
        }
    }
}
