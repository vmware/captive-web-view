// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto

import org.json.JSONObject
import java.lang.Exception

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import java.security.Key
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.spec.RSAKeyGenParameterSpec

class MainActivity: com.example.captivewebview.DefaultActivity() {
    // Android Studio warns that `ready` should start with a capital letter but
    // it shouldn't because it has to match what gets sent from the JS layer.
    private enum class Command {
        deleteAll, dump, generatePair, ready, UNKNOWN;

        companion object {
            fun matching(string: String?): Command? {
                return if (string == null) null
                else try { valueOf(string) }
                catch (exception: Exception) { UNKNOWN }
            }
        }
    }

    enum class KEY {
        parameters, alias, deleted, notDeleted, string, strings, count, keys,
        private, public, entry, info, exception, canonicalName, keySize,
        insideSecureHardware, purposes, encryptionPaddings, digests,
        userAuthenticationRequirementEnforcedBySecureHardware,
        AndroidKeyStore;

        override fun toString(): String {
            return this.name
        }
    }

    // Enables members of the KEY enumeration to be used as keys in mappings
    // from String to any, for example as mapOf() parameters.
    private infix fun <VALUE> KEY.to(that: VALUE): Pair<String, VALUE> {
        return this.name to that
    }

    private fun JSONObject.opt(key: KEY): Any? {
        return this.opt(key.name)
    }

    // fun KeyStore.Companion.getInstance(key: KEY): KeyStore {
    //    return KeyStore.getInstance(key.name)
    // }
    // This'd be nice but Kotlin can't extend the companion of a Java class.
    // https://stackoverflow.com/questions/33911457/how-can-one-add-static-methods-to-java-classes-in-kotlin

    companion object {
        private val purposeList = listOf(
            Pair(KeyProperties.PURPOSE_ENCRYPT, "encrypt")
            , Pair(KeyProperties.PURPOSE_DECRYPT, "decrypt")
            , Pair(KeyProperties.PURPOSE_SIGN, "sign")
            , Pair(KeyProperties.PURPOSE_VERIFY, "verify")
            // Next purpose requires API 28
            // , Pair(KeyProperties.PURPOSE_WRAP_KEY, "wrap")
        )

        // Utility function to take the `purposes` property bit map and turn it
        // into a list of strings.
        fun purposeStrings(keyInfo: KeyInfo):Array<String> {
            var mask:Int = 0
            val returning = mutableListOf<String>()
            purposeList.forEach {
                if (keyInfo.purposes and it.first != 0) {
                    mask = mask or it.first
                    returning.add(it.second)
                }
            }

            // Check if there's anything in the purposes map that isn't in the
            // purposesList. If there is, add an explanatory message to the
            // purposes strings.
            if (keyInfo.purposes != mask) {
                returning.add(listOf(
                    "Unmatched info:",
                    keyInfo.purposes.toString(2).padStart(8, '0')
                    , " returning:",
                    mask.toString(2).padStart(8, '0')
                ).joinToString(""))
            }

            return returning.toTypedArray()
        }
    }

    override fun commandResponse(
        command: String?,
        jsonObject: JSONObject
    ): JSONObject {
        return when(Command.matching(command)) {
            Command.deleteAll -> JSONObject(deleteAllKeys())

            Command.dump -> JSONObject(dumpKeyStore())

            Command.generatePair ->
                (jsonObject.opt(KEY.parameters) as? JSONObject)
                ?.run{ opt(KEY.alias) as? String }
                ?.let { JSONObject(generateKeyPair(it)) }
                ?: throw Exception(listOf(
                    "Key `", KEY.alias, "` must be specified in `",
                    KEY.parameters, "`."
                ).joinToString(""))

            Command.ready -> jsonObject

            else -> super.commandResponse(command, jsonObject)
        }
    }

    private fun deleteAllKeys(): Map<String, Any> {
        return try {
            val keyStore = KeyStore.getInstance(
                KEY.AndroidKeyStore.name
            ).apply { load(null) }
            val deleted = mutableListOf<String>()
            val notDeleted = mutableMapOf<String, String>()
            // Next part could maybe be done like this:
            //
            //     keyStore.aliases().toList().forEach { ... }
            //
            // However, it seems hazardous to delete from the key store in scope
            // of an iterator across the key store. So there's a separate
            // variable instead.
            val deleting = keyStore.aliases().toList()
            deleting.forEach {
                try {
                    keyStore.deleteEntry(it)
                    deleted.add(it)
                }
                catch (exception: Exception) {
                    notDeleted[it] = exception.toString()
                }
            }
            mapOf(KEY.deleted to deleted, KEY.notDeleted to notDeleted)
        }
        catch (exception: Exception) {
            mapOf(KEY.exception to exception.toString())
        }
    }

    private fun dumpKeyStore(): Map<String, Any> {
        return KeyStore.getInstance(KEY.AndroidKeyStore.name).apply {
            load(null)
        }.run { mapOf(
            KEY.string to toString(), KEY.count to size(),
            KEY.keys to aliases().toList().map { mapOf(
                KEY.entry to dumpKeyEntry(it),
                KEY.info to getKey(it, null).dumpKeyInfo()
            ) }
        )}
        // Near here, it would be quite nice to use `attributes` but it's
        // API level 26, which is too high.
    }

    private fun KeyStore.dumpKeyEntry(alias: String): Map<String, Any> {
        return try {
            // The getEntry() on the following line will generate an exception
            // in the adb logcat, but still returns a value, and doesn't throw
            // the exception in a way that can be caught.
            //
            // The exception starts with:
            // KeyStore exception android.os.ServiceSpecificException: (code 7)
            //
            // See: https://stackoverflow.com/a/52295484/7657675
            this.getEntry(alias, null)?.run { mapOf(
                KEY.canonicalName to javaClass.canonicalName,
                KEY.strings to toString().split("\n")
            ) } ?:
            throw Exception("getEntry(${alias},null) returned null.")
        }
        catch (exception: Exception) {
            mapOf(KEY.exception to exception.toString())
        }
    }

    private fun Key.dumpKeyInfo(): Map<String, Any> {
        return try {
            return KeyFactory.getInstance(
                this.algorithm, KEY.AndroidKeyStore.name
            ).getKeySpec(this, KeyInfo::class.java).run { mapOf(
                KEY.alias to keystoreAlias,
                KEY.keySize to keySize,
                KEY.purposes to purposeStrings(this),
                KEY.encryptionPaddings to encryptionPaddings,
                KEY.digests to digests,
                KEY.insideSecureHardware to isInsideSecureHardware,
                KEY.userAuthenticationRequirementEnforcedBySecureHardware to
                        isUserAuthenticationRequirementEnforcedBySecureHardware
            )}
        } catch (exception: Exception) {
            mapOf(KEY.exception to exception.toString())
        }
    }

    private fun generateKeyPair(alias:String): Map<String, Any> {
        // Code and comment here is originally from the Android developer
        // website.

        /*
         * Generate a new EC key pair entry in the Android Keystore by
         * using the KeyPairGenerator API. The private key can only be
         * used for signing or verification and only with SHA-256 or
         * SHA-512 as the message digest.
         */
        return KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_RSA, KEY.AndroidKeyStore.name
        ).apply { initialize(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            ).run {
                setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_RSA_OAEP)
//                setKeySize(4096)
                setAlgorithmParameterSpec(RSAKeyGenParameterSpec(
                    4096, RSAKeyGenParameterSpec.F4))
                setDigests(
                    KeyProperties.DIGEST_NONE, // KeyProperties.DIGEST_SHA256,
                    KeyProperties.DIGEST_SHA512)
                build()
            }
        ) }.generateKeyPair().run { mapOf(
            KEY.private to this.private.dumpKeyInfo(),
            KEY.public to this.public.dumpKeyInfo()
        )}
    }
}
