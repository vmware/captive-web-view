// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivity

import com.example.captivewebview.DefaultActivityMixIn
import org.json.JSONObject
import java.lang.Exception

class SpinnerActivity : com.example.captivewebview.DefaultActivity()  {

    // Android Studio warns that these should start with capital letters but
    // they shouldn't because they have to match what gets sent from the JS
    // layer.
    private enum class Command {
        getStatus, ready, UNKNOWN;

        companion object {
            fun matching(string: String?): Command? {
                return if (string == null) null
                else try {
                    Command.valueOf(string)
                }
                catch (exception: Exception) { UNKNOWN }
            }
        }
    }

    enum class Key { showLog, message }

    fun JSONObject.put(key: Key, value: Any): JSONObject {
        return this.put(key.name, value)
    }

    var polls = 0

    override fun commandResponse(
        command: String?,
        jsonObject: JSONObject
    ): JSONObject {
        return when(Command.matching(command)) {
            Command.getStatus -> {
                polls = (polls + 1) % 30
                jsonObject.put(Key.message, "Dummy status ${polls}.")
            }
            Command.ready -> jsonObject.put(Key.showLog, false)
            else -> super.commandResponse(command, jsonObject)
        }
    }

}