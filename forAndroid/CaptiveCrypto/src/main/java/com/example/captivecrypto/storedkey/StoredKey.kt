// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto.storedkey

import android.security.keystore.KeyProperties
import java.security.Key
import java.security.KeyStore

// Common code used by more than one file in the package.

enum class KEY {
    AndroidKeyStore;
}

fun loadKeyStore(name: String): KeyStore =
    KeyStore.getInstance(name).apply { load(null) }

fun cipherSpecifier(key: Key): String = when (key.algorithm) {
    // For the "AES/CBC/PKCS5PADDING" magic, TOTH:
    // https://developer.android.com/guide/topics/security/cryptography#encrypt-message
    // KeyProperties.KEY_ALGORITHM_AES -> "AES/CBC/PKCS5PADDING"
    KeyProperties.KEY_ALGORITHM_AES -> "AES/GCM/NoPADDING"

    KeyProperties.KEY_ALGORITHM_RSA -> "RSA/ECB/OAEPPadding"

    else -> key.algorithm
}

// Single API object for convenience import.
object StoredKey {
    fun describeAll() = describeAllStoredKeys()
    fun describeAll(providerName: String) = describeAllStoredKeys(providerName)
    fun deleteAll() = deleteAllStoredKeys()
    fun deleteAll(providerName: String) = deleteAllStoredKeys(providerName)
    fun generateKeyNamed(alias: String) = generateStoredKeyNamed(alias)
    fun generateKeyPairNamed(alias: String) = generateStoredKeyPairNamed(alias)
    fun describeKeyNamed(alias: String) = describeStoredKeyNamed(alias)
    fun encipherWithKeyNamed(plaintext:String, alias: String) =
        encipherWithStoredKey(plaintext, alias)
    fun decipherWithKeyNamed(ciphertext:EncipheredMessage, alias: String) =
        decipherWithStoredKey(ciphertext, alias)
}
// It'd be nicer to have a single function with an optional parameter for
// `providerName` but that seemed to generate errors like this.
//
//     java.lang.NoSuchMethodError: No virtual method ...
//
