// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import org.json.JSONObject

inline fun <reified T: Enum<T>> JSONObject.opt(key: T)
: Any? = opt(key.name)

inline fun <reified T: Enum<T>> JSONObject.put(key: T, value: Any?)
: JSONObject = put(key.name, value)

inline fun <reified T: Enum<T>> JSONObject.putOpt(key: T, value: Any?)
: JSONObject = putOpt(key.name, value)

inline fun <reified T: Enum<T>> JSONObject.remove(key: T)
: Any? = remove(key.name)

// Enables members of the any enumeration to be used as keys in mappings
// from String to any, for example as mapOf() parameters.
// Also blocks direct use of the enum in mappings.
inline infix fun <reified T: Enum<T>, VALUE> T.to(that: VALUE)
: Pair<String, VALUE> = this.name to that
