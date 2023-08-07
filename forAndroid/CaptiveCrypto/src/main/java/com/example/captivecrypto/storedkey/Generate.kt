// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto.storedkey

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import kotlinx.serialization.Serializable
import java.security.KeyPairGenerator
import javax.crypto.KeyGenerator

@Serializable
data class KeyGeneration(
    val provider: String,
    val sentinelCheck: String,
    val key: KeyDescription
)

fun generateStoredKeyNamed(
    alias: String, providerName: String = KEY.AndroidKeyStore.name
): KeyGeneration
{
    val keyGenerator = KeyGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_AES, providerName
    ).apply { init(
        KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        ).run {
            setKeySize(256)
            setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            build()
        }
    ) }

    val key = keyGenerator.generateKey()
    return KeyGeneration(
        keyGenerator.provider.name,
        generationSentinel(alias).name,
        key.description
    )
}

fun generateStoredKeyPairNamed(
    alias: String, providerName: String = KEY.AndroidKeyStore.name
): KeyGeneration {
    val keyPairGenerator = KeyPairGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_RSA, providerName
    ).apply { initialize(
        KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        ).run {
            setBlockModes(KeyProperties.BLOCK_MODE_ECB)
            setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
            setDigests(
                KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)
            build()
        }
    ) }
    val keyPair = keyPairGenerator.generateKeyPair()
    return KeyGeneration(
        keyPairGenerator.provider.name,
        generationSentinel(alias).name,
        keyPair.private.description
    )
    // keyPair.public isn't included here.
}

private enum class GenerationSentinelResult {
    Passed, Failed;

    companion object {
        fun <TYPE:Comparable<TYPE>>comparing(first:TYPE, second:TYPE)
                :GenerationSentinelResult
        {
            return if (first.compareTo(second) == 0) Passed else Failed
        }
    }
}

private fun generationSentinel(keyAlias: String): GenerationSentinelResult
{
    val sentinel = "InMemorySentinel"
    val encrypted = encipherWithStoredKey(sentinel, keyAlias)
    val decrypted = decipherWithStoredKey(encrypted, keyAlias)
    return GenerationSentinelResult.comparing(sentinel, decrypted)
}
