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
        insideSecureHardware,
        userAuthenticationRequirementEnforcedBySecureHardware;

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

    companion object {
        const val ANDROID_KEY_STORE = "AndroidKeyStore"
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
            val keyStore = KeyStore.getInstance(ANDROID_KEY_STORE).apply {
                load(null)
            }
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
            mapOf(KEY.exception.name to exception.toString())
        }
    }

    private fun dumpKeyStore(): Map<String, Any> {
        return KeyStore.getInstance(ANDROID_KEY_STORE).apply {
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
                this.algorithm, ANDROID_KEY_STORE
            ).getKeySpec(this, KeyInfo::class.java).run { mapOf(
                KEY.keySize to keySize,
                KEY.insideSecureHardware to isInsideSecureHardware,
                KEY.alias to keystoreAlias,
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
            KeyProperties.KEY_ALGORITHM_EC, ANDROID_KEY_STORE
        ).apply { initialize(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_SIGN or KeyProperties.PURPOSE_VERIFY
            ).run {
                setDigests(
                    KeyProperties.DIGEST_SHA256, KeyProperties.DIGEST_SHA512
                )
                build()
            }
        ) }.generateKeyPair().run { mapOf(
            KEY.private to this.private.dumpKeyInfo(),
            KEY.public to this.public.dumpKeyInfo()
        )}
    }
}
