// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto.storedkey

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
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
    var generator = keyGeneratorStrongBox(alias, providerName)
    val key = try {
        generator.generateKey()
    }
    catch (exception: StrongBoxUnavailableException) {
        generator = keyGeneratorGeneric(alias, providerName)
        generator.generateKey()
    }

    return KeyGeneration(
        generator.provider.name,
        generationSentinel(alias).name,
        key.description
    )
}

fun keyGeneratorStrongBox(alias: String, providerName: String): KeyGenerator =
    KeyGenerator.getInstance(
        KeyProperties.KEY_ALGORITHM_AES, providerName
    ).apply { init(
        KeyGenParameterSpec.Builder(
            alias,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
        ).run {
            setKeySize(256)
            setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            setIsStrongBoxBacked(true)
            build()
        }
    ) }

fun keyGeneratorGeneric(alias: String, providerName: String): KeyGenerator =
    KeyGenerator.getInstance(
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

fun generateStoredKeyPairNamed(
    alias: String, providerName: String = KEY.AndroidKeyStore.name
): KeyGeneration {
    var generator = keyPairGeneratorStrongBox(alias, providerName)
    val keyPair = try {
        generator.generateKeyPair()
    }
    catch (exception: StrongBoxUnavailableException) {
        generator = keyPairGeneratorGeneric(alias, providerName)
        generator.generateKeyPair()
    }

    return KeyGeneration(
        generator.provider.name,
        generationSentinel(alias).name,
        keyPair.private.description
    )
    // keyPair.public isn't included here.
}

private fun keyPairGeneratorGeneric(
    alias: String, providerName: String
): KeyPairGenerator = KeyPairGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_RSA, providerName
).apply { initialize(
    KeyGenParameterSpec.Builder(
        alias,
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
    ).run {
        setForRSA()
        build()
    }
) }

private fun keyPairGeneratorStrongBox(
    alias: String, providerName: String
): KeyPairGenerator = KeyPairGenerator.getInstance(
    KeyProperties.KEY_ALGORITHM_RSA, providerName
).apply { initialize(
    KeyGenParameterSpec.Builder(
        alias,
        KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
    ).run {
        setForRSA()
        setIsStrongBoxBacked(true)
        build()
    }
) }

private fun KeyGenParameterSpec.Builder.setForRSA() {
    setBlockModes(KeyProperties.BLOCK_MODE_ECB)
    setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
    setDigests(
        KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512)

    // Set an attestation challenge so that a chain of trust will be generated.
    // The challenge here is an empty byte array; any non-null value causes the
    // chain of trust to be generated.
    //
    // TOTH for the need to call this:
    // https://stackoverflow.com/a/64797384/7657675
    setAttestationChallenge(byteArrayOf())
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
