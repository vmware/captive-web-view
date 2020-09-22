// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto

import android.os.Build
import android.security.keystore.KeyGenParameterSpec
import org.json.JSONObject

import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import org.json.JSONArray
import java.security.*
import java.text.SimpleDateFormat
import java.util.*
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.OAEPParameterSpec
import kotlin.Exception

class MainActivity: com.example.captivewebview.DefaultActivity() {
    // Android Studio warns that `ready` should start with a capital letter but
    // it shouldn't because it has to match what gets sent from the JS layer.
    private enum class Command {
        capabilities, deleteAll, encrypt, summariseStore,
        generateKey, generatePair, ready, UNKNOWN;

        companion object {
            fun matching(string: String?): Command? {
                return if (string == null) null
                else try { valueOf(string) }
                catch (exception: Exception) { UNKNOWN }
            }
        }
    }

    enum class KEY {
        parameters, alias, deleted, notDeleted, string, count, keys,
        private, public, entry, info, exception, canonicalName, keySize,
        insideSecureHardware, purposes, encryptionPaddings, digests,
        userAuthenticationRequirementEnforcedBySecureHardware, encoded,
        blockModes,

        summary, services, algorithm, `class`, type,

        digest, provider, iv, sentinel, encryptedSentinel, decryptedSentinel,
        passed,

        testResults,

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

    private fun JSONObject.put(key: KEY, value: Any?): JSONObject {
        return this.put(key.name, value)
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

        private val formats = listOf("dd", "MMM", "yyyy HH:MM", " z")
        private val formatters = formats.map { SimpleDateFormat(it) }
        private fun fancyFormatted(date:Date, withZone:Boolean):String {
            return formatters.withIndex()
                .filter { withZone || it.index < formats.size - 1 }
                .map {
                    val piece: String = it.value.format(date)
                    if (it.index == 1) piece.toLowerCase() else piece
                }
                .joinToString("")
        }

        fun providersSummary():Map<String, Any> {
            val returning = mutableMapOf<String, Any>(
                "build" to mapOf(
                    "device" to Build.DEVICE,
                    "display" to Build.DISPLAY,
                    "manufacturer" to Build.MANUFACTURER,
                    "model" to Build.MODEL,
                    "brand" to Build.BRAND,
                    "product" to Build.PRODUCT,
                    "time" to fancyFormatted(Date(Build.TIME), false)
                ),
                "date" to fancyFormatted(Date(), true)
            )
            return Security.getProviders().map {
                it.name to it.toMap()
            }.toMap(returning)
        }

        fun providerSummay(providerName:String):Map<String, Any> {
            return Security.getProvider(providerName).run { mapOf(
                name to mapOf(
                    KEY.string to toString(),
                    KEY.summary to toMap(),
                    KEY.services to services.map { service -> mapOf(
                        KEY.algorithm to service.algorithm,
                        KEY.`class` to service.className,
                        KEY.type to service.type,
                        KEY.summary to service.toString()
                    )}
                )
            ) }
        }

        fun cipherSpecifier(key: Key): String { return when (key.algorithm) {

            // For the "AES/CBC/PKCS5PADDING" magic, TOTH:
            // https://developer.android.com/guide/topics/security/cryptography#encrypt-message
            // KeyProperties.KEY_ALGORITHM_AES -> "AES/CBC/PKCS5PADDING"
            KeyProperties.KEY_ALGORITHM_AES -> "AES/GCM/NoPADDING"

            KeyProperties.KEY_ALGORITHM_RSA -> "RSA/ECB/OAEPPadding"

            else -> key.algorithm

        } }

        fun loadKeyStore(name: String = KEY.AndroidKeyStore.name): KeyStore {
            return KeyStore.getInstance(name).apply { load(null) }
        }
    }

    override fun commandResponse(
        command: String?,
        jsonObject: JSONObject
    ): JSONObject {
        return when(Command.matching(command)) {
            Command.capabilities -> JSONObject(providersSummary())

            Command.deleteAll -> JSONObject(deleteAllKeys())

            Command.encrypt -> {
                val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "`."
                    ).joinToString(""))
                val alias = parameters.opt(KEY.alias) as? String
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "` with `", KEY.alias, "` element."
                    ).joinToString(""))
                val sentinel = parameters.opt(KEY.sentinel) as? String
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "` with `", KEY.sentinel, "` element."
                    ).joinToString(""))

                jsonObject.put(KEY.testResults, testKey(alias, sentinel))
            }

            Command.summariseStore -> jsonObject.put("keyStore", JSONArray(
                loadKeyStore().summarise()
            ))

            Command.generateKey ->
                (jsonObject.opt(KEY.parameters) as? JSONObject)
                    ?.run{ opt(KEY.alias) as? String }
                    ?.let { JSONObject(generateKey(it)) }
                    ?: throw Exception(listOf(
                        "Key `", KEY.alias, "` must be specified in `",
                        KEY.parameters, "`."
                    ).joinToString(""))

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
            val keyStore = loadKeyStore()
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

    private fun KeyStore.summarise(): List<Map<String, Any>> {
        return aliases().toList().map {
            val keySummary = this.getKey(it, null).summarise().toMutableMap()

            mapOf(
                "store" to "",
                "name" to it,
                "type" to keySummary[KEY.algorithm.name] as String,
                "summary" to summariseEntry(it).toMap(keySummary)
            )
        }
    }

     fun KeyStore.summariseEntry(alias: String): Map<String, Any> {
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
                KEY.summary to toString().split("\n")
            ) } ?:
            throw Exception("getEntry(${alias},null) returned null.")
        }
        catch (exception: Exception) {
            mapOf(KEY.exception to exception.toString())
        }

        // Near here, it would be quite nice to use `attributes` but it's
        // API level 26, which is too high.
    }

    private fun Key.summarise(): Map<String, Any> {
        return try {
            return KeyFactory.getInstance(
                this.algorithm, KEY.AndroidKeyStore.name
            ).getKeySpec(this, KeyInfo::class.java).run {
                mapOf(
                    KEY.alias to keystoreAlias,
                    KEY.algorithm to algorithm,
                    KEY.keySize to keySize,
                    KEY.blockModes to blockModes,
                    KEY.purposes to purposeStrings(this),
                    KEY.encryptionPaddings to encryptionPaddings,
                    KEY.digests to digests,
                    KEY.insideSecureHardware to isInsideSecureHardware,
                    KEY.userAuthenticationRequirementEnforcedBySecureHardware to
                            isUserAuthenticationRequirementEnforcedBySecureHardware
                )
            }
        }
        catch (exception: NoSuchAlgorithmException) { mapOf(
            // This exception is raised if the key store can't transform a key
            // of this algorithm into a key specification. This is true of AES,
            // for example.
            KEY.encoded to (this.encoded?.toString() ?: "No encoded form."),
            KEY.algorithm to this.algorithm
        ) }
        catch (exception: Exception) {
            // Some other exception.

            // Some have multiple sentences and get too long. Change those into
            // an array.
            val texts = exception.toString().splitToSequence(". ").toList()

            mapOf(
                KEY.exception to if (texts.size == 1) texts[0] else texts,
                KEY.encoded to (this.encoded?.toString() ?: "null"),
                KEY.algorithm to this.algorithm
            )
        }
    }

    private fun testKey(alias: String, sentinel: String): JSONArray {
        val key = loadKeyStore().getKey(alias, null)
        val getKeyResult = JSONObject(
            key?.summarise()
                ?: mapOf("failed" to "getKey(${alias}, null) returned null.")
        )


        return JSONArray(listOf(getKeyResult))
    }

    private fun generateKey(alias:String): Map<String, Any> {
        val keyGenerator = KeyGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_AES, KEY.AndroidKeyStore.name
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

        return keyGenerator.generateKey().let { mapOf(
            KEY.sentinel to encryptSentinel("Single tient", it),
            "provider" to keyGenerator.provider.name,
            "key" to it.summarise()
        ) }
    }

    private fun generateKeyPair(alias:String): Map<String, Any> {
        val keyPairGenerator = KeyPairGenerator.getInstance(
            KeyProperties.KEY_ALGORITHM_RSA, KEY.AndroidKeyStore.name
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
        return keyPairGenerator.generateKeyPair().let { mapOf(
            KEY.sentinel to encryptSentinel("Sentient", it),
            KEY.provider to keyPairGenerator.provider.name,
            KEY.private to it.private.summarise(),
            KEY.public to it.public.summarise()
        ) }
    }

    private fun encryptSentinel(
        sentinel: String, key: SecretKey
    ): Map<String, Any>
    {
        val cipher = Cipher.getInstance(cipherSpecifier(key))

        cipher.init(Cipher.ENCRYPT_MODE, key)
        val sentinelBytes = sentinel.toByteArray(Charsets.UTF_8)
        val encryptedSentinel = cipher.doFinal(sentinelBytes)

        // The IV wasn't specified above. This means that the cipher will create
        // a random one of its own. It has to be extracted in order to do the
        // decryption leg.

        // In CBC mode, only the IV need be specified. In GCM mode, the tag id
        // length must also be specified.

        // For IvParameterSpec, TOTH:
        // https://medium.com/@hakkitoklu/aes256-encryption-decryption-in-android-2fae6938fc2b
        // val parameterSpec = IvParameterSpec(cipher.iv)

        // For GCMParameterSpec, TOTH:
        // https://medium.com/@josiassena/using-the-android-keystore-system-to-store-sensitive-information-3a56175a454b
        val parameterSpec = GCMParameterSpec(128, cipher.iv)

        // Now re-initialise for decryption and insert back the IV.
        cipher.init(Cipher.DECRYPT_MODE, key, parameterSpec)

        // In CBC mode, if you don't set an IV spec, you get this:
        //
        //     java.lang.RuntimeException:
        //     java.security.InvalidAlgorithmParameterException:
        //     IV must be specified in CBC mode

        val decryptedSentinel = String(
            cipher.doFinal(encryptedSentinel), Charsets.UTF_8)

        return mapOf(
            KEY.algorithm to cipher.algorithm,
            KEY.provider to cipher.provider.name,
            KEY.iv to cipher.iv,
            KEY.sentinel to sentinel,
            KEY.encryptedSentinel to encryptedSentinel.toString(),
            KEY.decryptedSentinel to decryptedSentinel,
            KEY.passed to sentinel.equals(decryptedSentinel)
        )
    }

    private fun encryptSentinel(
        sentinel: String, keyPair: KeyPair
    ): Map<String, Any> {
        val cipher = Cipher.getInstance(cipherSpecifier(keyPair.public))

        // Create a parameter specification based on the default but changing
        // the digest algorithm to SHA-512. The default would be SHA-1, which is
        // generally deprecated.
        val oaepParameterSpec = OAEPParameterSpec(
            KeyProperties.DIGEST_SHA512,
            OAEPParameterSpec.DEFAULT.mgfAlgorithm,
            OAEPParameterSpec.DEFAULT.mgfParameters,
            OAEPParameterSpec.DEFAULT.pSource
        )

        // Encrypt with the public key.
        cipher.init(Cipher.ENCRYPT_MODE, keyPair.public, oaepParameterSpec)
        val encryptedBytes = cipher.doFinal(
            sentinel.toByteArray(Charsets.UTF_8))

        // Decrypt with the private key.
        cipher.init(Cipher.DECRYPT_MODE, keyPair.private, oaepParameterSpec)
        val decryptedSentinel = String(cipher.doFinal(
            encryptedBytes), Charsets.UTF_8)

        // If there are no digest algorithms in common between the
        // OAEPParameterSpec and the key, you get this exception ...
        // java.security.InvalidKeyException: Keystore operation failed
        // ... with this cause
        // android.security.KeyStoreException: Incompatible digest

        return mapOf(
            KEY.algorithm to cipher.algorithm,
            KEY.provider to cipher.provider.name,
            KEY.digest to oaepParameterSpec.digestAlgorithm,
            KEY.iv to cipher.iv,
            KEY.sentinel to sentinel,
            KEY.encryptedSentinel to encryptedBytes.toString(),
            KEY.decryptedSentinel to decryptedSentinel,
            KEY.passed to sentinel.equals(decryptedSentinel)
        )
    }
}
