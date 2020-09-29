// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import kotlinx.serialization.*
import java.security.*
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.OAEPParameterSpec

private enum class KEY {
    AndroidKeyStore;
}

object StoredKey {

    private enum class KeyPurpose(val mask:Int) {
        encrypt(KeyProperties.PURPOSE_ENCRYPT),
        decrypt(KeyProperties.PURPOSE_DECRYPT),
        sign(KeyProperties.PURPOSE_SIGN),
        verify(KeyProperties.PURPOSE_VERIFY);

        // Next purpose requires API 28
        // wrap(KeyProperties.PURPOSE_WRAP_KEY)

        companion object {
            // Utility function to take the `purposes` property bit map and turn it
            // into a list of strings.
            fun purposeStrings(keyInfo: KeyInfo):List<String> {
                var mask:Int = 0
                val returning = mutableListOf<String>()
                values().forEach {
                    if (keyInfo.purposes and it.mask != 0) {
                        mask = mask or it.mask
                        returning.add(it.name)
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

                return returning
            }

        }
    }

    val KeyInfo.purposeStrings:List<String>
            get() = KeyPurpose.purposeStrings(this)

    fun loadKeyStore(name: String = MainActivity.KEY.AndroidKeyStore.name): KeyStore {
        return KeyStore.getInstance(name).apply { load(null) }
    }

    @Serializable
    data class Deletion(
        val deleted:List<String>, val notDeleted:Map<String, String>
    )

    fun deleteAll(): Deletion {
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
        return Deletion(deleted.toList(), notDeleted)
    }

    fun describeKeyNamed(alias:String):String {
        val keyStore = loadKeyStore()
        val entry = keyStore.getEntry(alias, null)
            ?: throw Exception("No store entry with alias \"$alias\".")
        val key = keyStore.getKey(alias, null)
            ?: throw Exception("No key with alias \"$alias\".")
        return if (entry is KeyStore.PrivateKeyEntry)
            KeyStore.PrivateKeyEntry::class.java.simpleName
        else if (entry is KeyStore.SecretKeyEntry)
            KeyStore.SecretKeyEntry::class.java.simpleName
        else entry.toString()
    }

    @Serializable
    data class EntryDescription(
        // Properties of the key store entry.
        val name: String,
        val type: String,
        val key: KeyDescription,
        val entryClassName: String,
        val summary: List<String>
    )

    @Serializable
    sealed class KeyDescription {
        abstract val algorithm: String

        @Serializable
        data class Full(
            // Properties of the Key.
            val keyClassName: String,
            val alias: String,
            override val algorithm: String,
            val keySize: Int,
            val blockModes: List<String>,
            val purposes: List<String>,
            val encryptionPaddings: List<String>,
            val digests: List<String>,
            val insideSecureHardware: Boolean,
            val userAuthenticationRequirementEnforcedBySecureHardware: Boolean
        ) : KeyDescription()

        @Serializable
        sealed class Partial: KeyDescription() {
            abstract val encoded: String

            @Serializable
            data class NoKey(
                override val encoded: String,
                override val algorithm: String
            ) : Partial()

            @Serializable
            data class KeyFactoryShortException(
                val exception: String,
                override val encoded: String,
                override val algorithm: String
            ) : Partial()

            @Serializable
            data class KeyFactoryLongException(
                val exception: List<String>,
                override val encoded: String,
                override val algorithm: String
            ) : Partial()
        }
    }

    private val Key.description: KeyDescription get() {
        val canonicalName = javaClass.canonicalName
        return try {
            KeyFactory.getInstance(
                this.algorithm, KEY.AndroidKeyStore.name
            ).getKeySpec(this, KeyInfo::class.java).run {
                KeyDescription.Full(
                    canonicalName,
                    keystoreAlias,
                    algorithm,
                    keySize,
                    blockModes.asList(),
                    purposeStrings,
                    encryptionPaddings.asList(),
                    digests.asList(),
                    isInsideSecureHardware,
                    isUserAuthenticationRequirementEnforcedBySecureHardware
                )
            }
        }
        catch (exception: NoSuchAlgorithmException) {
            // This exception is raised if the key store can't transform a key
            // of this algorithm into a key specification. This is true of AES,
            // for example.
            KeyDescription.Partial.NoKey(
                encoded?.toString() ?: "No encoded form.", algorithm
            )
        }
        catch (exception: Exception) {
            // Some other exception.

            // Some have multiple sentences and get too long. Change those into
            // an array.
            val texts = exception.toString().splitToSequence(". ").toList()
            val keyEncoded = encoded?.toString() ?: "null"
            if (texts.size == 1) KeyDescription.Partial.KeyFactoryShortException(
                texts[0], keyEncoded, algorithm
            )
            else KeyDescription.Partial.KeyFactoryLongException(
                texts, keyEncoded, algorithm
            )
        }
    }

    fun describeAll(providerName: String = KEY.AndroidKeyStore.name)
            : List<EntryDescription>
    {
        return loadKeyStore(providerName).describeAll()
    }

    private fun KeyStore.describeAll(): List<EntryDescription> {
        return aliases().toList().map {
            // The getEntry() on the following line will generate an exception
            // in the adb logcat, but still returns a value, and doesn't throw
            // the exception in a way that can be caught.
            //
            // The exception starts with:
            // KeyStore exception android.os.ServiceSpecificException: (code 7)
            //
            // See: https://stackoverflow.com/a/52295484/7657675
            val entry = getEntry(it, null)
                ?: throw Exception("No store entry with alias \"$it\".")
            val keyDescription = getKey(it, null)?.description
                ?: throw Exception("No key with alias \"$it\".")
            val canonicalName = if (entry is KeyStore.PrivateKeyEntry)
                KeyStore.PrivateKeyEntry::class.java.simpleName
            else if (entry is KeyStore.SecretKeyEntry)
                KeyStore.SecretKeyEntry::class.java.simpleName
            else entry.toString()

            EntryDescription(
                it,
                keyDescription.algorithm,
                keyDescription,
                canonicalName,
                entry.toString().split("\n")
            )
        }

        // Near here, it would be quite nice to use `attributes` but it's
        // API level 26, which is too high.

        // It might seem more consistent to have KeyStore.Entry extension like
        // .description that returns an EntryDescription. However, the entry
        // description includes a KeyDescription, which can only be generated by
        // the Key. The Key isn't accessible from the KeyEntry.
    }

    @Serializable
    data class KeyGeneration(val provider: String, val key: KeyDescription)

    fun generateKeyWithName(alias: String): KeyGeneration
    {
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

        val key = keyGenerator.generateKey()
        return KeyGeneration(keyGenerator.provider.name, key.description)
    }

    fun generateKeyPairWithName(alias: String): KeyGeneration {
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
        val keyPair = keyPairGenerator.generateKeyPair()
        return KeyGeneration(
            keyPairGenerator.provider.name, keyPair.private.description
        )
        // keyPair.public isn't included here.
    }

    private fun cipherSpecifier(key: Key): String { return when (key.algorithm) {

        // For the "AES/CBC/PKCS5PADDING" magic, TOTH:
        // https://developer.android.com/guide/topics/security/cryptography#encrypt-message
        // KeyProperties.KEY_ALGORITHM_AES -> "AES/CBC/PKCS5PADDING"
        KeyProperties.KEY_ALGORITHM_AES -> "AES/GCM/NoPADDING"

        KeyProperties.KEY_ALGORITHM_RSA -> "RSA/ECB/OAEPPadding"

        else -> key.algorithm

    } }

    @Serializable
    data class EncryptedMessage(
        val ciphertext:ByteArray,
        val iv:ByteArray?,
        val provider:String,
        val algorithm: String,
        val digest: String?
    )

    fun encryptWithStoredKey(
        plaintext: String,
        alias: String,
        providerName: String = MainActivity.KEY.AndroidKeyStore.name
    ): EncryptedMessage
    {
        val keyStore = loadKeyStore(providerName)
        val entry = keyStore.getEntry(alias, null)
        val key = when(entry) {
            is KeyStore.PrivateKeyEntry ->
                // Encrypt with the public key. The public key isn't stored
                // as a key; it is stored in a certificate that is created
                // by the creation of the private key.
                keyStore.getCertificate(alias).publicKey

            is KeyStore.SecretKeyEntry -> entry.secretKey

            else -> throw Exception(listOf(
                "Cannot encrypt with stored item \"${alias}\".",
                " Summary of entry:${entry}."
            ).joinToString(""))
        }

        val parameterSpec = when(key.algorithm) {

            // For RSA: Create a parameter specification based on the
            // default but changing the digest algorithm to SHA-512. The
            // default would be SHA-1, which is generally deprecated.
            KeyProperties.KEY_ALGORITHM_RSA -> OAEPParameterSpec(
                KeyProperties.DIGEST_SHA512,
                OAEPParameterSpec.DEFAULT.mgfAlgorithm,
                OAEPParameterSpec.DEFAULT.mgfParameters,
                OAEPParameterSpec.DEFAULT.pSource
            )

            // For AES: Don't specify an IV so a random one will be
            // generated.
            KeyProperties.KEY_ALGORITHM_AES -> null

            else -> throw Exception(listOf(
                "Cannot encrypt with stored item \"${alias}\".",
                " Unsupported algorithm: \"${key.algorithm}\"."
            ).joinToString(""))
        }

        val cipher = Cipher.getInstance(cipherSpecifier(key))

        cipher.init(Cipher.ENCRYPT_MODE, key, parameterSpec)
        val encryptedBytes = cipher.doFinal(
            plaintext.toByteArray(Charsets.UTF_8)
        )

        return EncryptedMessage(
            encryptedBytes,
            cipher.iv,
            cipher.provider.name,
            cipher.algorithm,
            (parameterSpec as? OAEPParameterSpec)?.digestAlgorithm
        )
    }

    fun decryptWithStoredKey(
        encryptedMessage: EncryptedMessage,
        alias: String,
        providerName: String = MainActivity.KEY.AndroidKeyStore.name
    ): String
    {
        val keyStore = loadKeyStore(providerName)
        val entry = keyStore.getEntry(alias, null)
        val key:Key = when(entry) {
            // Decrypt with the private key.
            is KeyStore.PrivateKeyEntry -> entry.privateKey

            is KeyStore.SecretKeyEntry -> entry.secretKey

            else -> throw Exception(listOf(
                "Cannot decrypt with stored item \"${alias}\".",
                " Summary of entry:${entry}."
            ).joinToString(""))
        }

        // Next statement creates a parameter specification object. In this
        // version, assumptions are made, about block mode, RSA digest and
        // padding for example. In an ideal version, those parameters would
        // be deduced from the key entry, or would be passed in to this
        // function maybe.
        val parameterSpec = when(key.algorithm) {

            // For RSA: Create a parameter specification based on the
            // default but changing the digest algorithm to SHA-512. The
            // default would be SHA-1, which is generally deprecated.
            KeyProperties.KEY_ALGORITHM_RSA -> OAEPParameterSpec(
                KeyProperties.DIGEST_SHA512,
                OAEPParameterSpec.DEFAULT.mgfAlgorithm,
                OAEPParameterSpec.DEFAULT.mgfParameters,
                OAEPParameterSpec.DEFAULT.pSource
            )
            // If there are no digest algorithms in common between the
            // OAEPParameterSpec and the key, you get this exception ...
            // java.security.InvalidKeyException: Keystore operation failed
            // ... with this cause
            // android.security.KeyStoreException: Incompatible digest

            // For AES, an IV is needed. It will have been created at or
            // before encrypting time.

            // In CBC mode, only the IV need be specified. In GCM mode, the tag id
            // length must also be specified.

            // In CBC mode, if you don't set an IV spec, you get this:
            //
            //     java.lang.RuntimeException:
            //     java.security.InvalidAlgorithmParameterException:
            //     IV must be specified in CBC mode

            // For IvParameterSpec, TOTH:
            // https://medium.com/@hakkitoklu/aes256-encryption-decryption-in-android-2fae6938fc2b
            // val parameterSpec = IvParameterSpec(cipher.iv)

            // For GCMParameterSpec, TOTH:
            // https://medium.com/@josiassena/using-the-android-keystore-system-to-store-sensitive-information-3a56175a454b
            KeyProperties.KEY_ALGORITHM_AES ->
                GCMParameterSpec(128, encryptedMessage.iv)

            else -> throw Exception(listOf(
                "Cannot decrypt with stored item \"${alias}\".",
                " Unsupported algorithm: \"${key.algorithm}\"."
            ).joinToString(""))
        }

        val cipher = Cipher.getInstance(cipherSpecifier(key))

        cipher.init(Cipher.DECRYPT_MODE, key, parameterSpec)
        return String(cipher.doFinal(
            encryptedMessage.ciphertext), Charsets.UTF_8)
    }
}