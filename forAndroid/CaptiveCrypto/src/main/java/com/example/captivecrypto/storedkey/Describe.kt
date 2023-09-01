// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto.storedkey

import android.os.Build
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Base64
import kotlinx.serialization.Serializable
import java.security.Key
import java.security.KeyFactory
import java.security.KeyStore
import java.security.NoSuchAlgorithmException
import java.security.cert.Certificate
import java.security.cert.X509Certificate
import javax.crypto.SecretKey
import javax.crypto.SecretKeyFactory

fun describeAllStoredKeys(providerName: String = KEY.AndroidKeyStore.name)
        : List<EntryDescription> = loadKeyStore(providerName).describeAllKeys()

fun describeStoredKeyNamed(
    alias: String, providerName: String = KEY.AndroidKeyStore.name
) : EntryDescription = loadKeyStore(providerName).describeKeyNamed(alias)

@Serializable
data class EntryDescription(
    // Properties of the key store entry.
    val name: String,
    val type: String,
    val entryClassName: String,
    val certificateChain: List<String>?,
    val summary: List<String>,
    val key: KeyDescription
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
        val userAuthenticationRequirementEnforcedBySecureHardware: Boolean,
        val securityLevel: String
    ) : KeyDescription()

    @Serializable
    sealed class Partial: KeyDescription() {
        abstract val encoded: String

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

val Key.description: KeyDescription
    get() = try {
        try {
            KeyFactory.getInstance(
                this.algorithm, KEY.AndroidKeyStore.name
            ).getKeySpec(this, KeyInfo::class.java)
        }
        catch (exception: NoSuchAlgorithmException) {
            SecretKeyFactory.getInstance(
                this.algorithm, KEY.AndroidKeyStore.name
            ).getKeySpec(this as SecretKey?, KeyInfo::class.java) as KeyInfo
        }.run {
            KeyDescription.Full(
                this@description.javaClass.canonicalName ?: "",
                keystoreAlias,
                algorithm,
                keySize,
                blockModes.asList(),
                purposeStrings,
                encryptionPaddings.asList(),
                digests.asList(),
                insideSecureHardware(this),
                isUserAuthenticationRequirementEnforcedBySecureHardware,
                securityLevel(this)
            )
        }
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

private fun insideSecureHardware(keyInfo: KeyInfo): Boolean =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        keyInfo.securityLevel == KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT
                || keyInfo.securityLevel == KeyProperties.SECURITY_LEVEL_STRONGBOX
    } else {
        keyInfo.isInsideSecureHardware
    }

private fun securityLevel(keyInfo: KeyInfo): String =
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
        when(keyInfo.securityLevel) {
            KeyProperties.SECURITY_LEVEL_SOFTWARE ->
                "SECURITY_LEVEL_SOFTWARE"

            KeyProperties.SECURITY_LEVEL_STRONGBOX ->
                "SECURITY_LEVEL_STRONGBOX"

            KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT ->
                "SECURITY_LEVEL_TRUSTED_ENVIRONMENT"

            KeyProperties.SECURITY_LEVEL_UNKNOWN -> "SECURITY_LEVEL_UNKNOWN"

            KeyProperties.SECURITY_LEVEL_UNKNOWN_SECURE ->
                "SECURITY_LEVEL_UNKNOWN_SECURE"

            else -> keyInfo.securityLevel.toString()
        }
    else unavailableMessage(Build.VERSION_CODES.S)

private fun KeyStore.describeAllKeys(): List<EntryDescription> =
    aliases().toList().map { this.describeKeyNamed(it) }

private fun KeyStore.describeKeyNamed(alias:String):EntryDescription {
    // The getEntry() on the following line will generate an exception
    // in the adb logcat, but still returns a value, and doesn't throw
    // the exception in a way that can be caught.
    //
    // The exception starts with:
    // KeyStore exception android.os.ServiceSpecificException: (code 7)
    //
    // See: https://stackoverflow.com/a/52295484/7657675
    val entry = getEntry(alias, null)
        ?: throw Exception("No store entry with alias \"$alias\".")
    val keyDescription = getKey(alias, null)?.description
        ?: throw Exception("No key with alias \"$alias\".")

    return EntryDescription(
        alias,
        keyDescription.algorithm,

        when (entry) {
            is KeyStore.PrivateKeyEntry ->
                KeyStore.PrivateKeyEntry::class.java.simpleName
            is KeyStore.SecretKeyEntry ->
                KeyStore.SecretKeyEntry::class.java.simpleName
            else -> entry.toString()
        },

        // Get the certificate chain from the KeyStore as described here.
        // https://developer.android.com/training/articles/security-key-attestation#verifying
        //
        // An alternative could be to get it from the Entry like this.
        //
        //     (entry as? PrivateKeyEntry)?.certificateChain
        certificatesDescription(getCertificateChain(alias)),

        entry.toString().split("\n"),
        keyDescription
    )

    // Near here, it would be quite nice to use `attributes` but it's
    // API level 26, which is too high.

    // It might seem more consistent to have KeyStore.Entry extension like
    // .description that returns an EntryDescription. However, the entry
    // description includes a KeyDescription, which can only be generated by
    // the Key. The Key isn't accessible from the KeyEntry.
}

private fun certificatesDescription(certificates: Array<Certificate>?) =
    certificates?.map { certificate ->
        (certificate as? X509Certificate)?.run {
            val publicKeyB64 = Base64.encode(publicKey.encoded, Base64.NO_WRAP)
                .decodeToString().filterNot { it.isWhitespace() }
            if (publicKeyB64 == hardwareAttestationRootPublicKeyB64)
                "hardwareAttestationRoot"
            else X509Certificate::class.java.simpleName
        }
            ?: certificate.type
    }

// Hardware attestation root public key pasted from here.
// https://developer.android.com/training/articles/security-key-attestation#root_certificate
private val hardwareAttestationRootPublicKeyB64 = (
        "MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAr7bHgiuxpwHsK7Qui8xU\n" +
                "  FmOr75gvMsd/dTEDDJdSSxtf6An7xyqpRR90PL2abxM1dEqlXnf2tqw1Ne4Xwl5j\n" +
                "  lRfdnJLmN0pTy/4lj4/7tv0Sk3iiKkypnEUtR6WfMgH0QZfKHM1+di+y9TFRtv6y\n" +
                "  //0rb+T+W8a9nsNL/ggjnar86461qO0rOs2cXjp3kOG1FEJ5MVmFmBGtnrKpa73X\n" +
                "  pXyTqRxB/M0n1n/W9nGqC4FSYa04T6N5RIZGBN2z2MT5IKGbFlbC8UrW0DxW7AYI\n" +
                "  mQQcHtGl/m00QLVWutHQoVJYnFPlXTcHYvASLu+RhhsbDmxMgJJ0mcDpvsC4PjvB\n" +
                "  +TxywElgS70vE0XmLD+OJtvsBslHZvPBKCOdT0MS+tgSOIfga+z1Z1g7+DVagf7q\n" +
                "  uvmag8jfPioyKvxnK/EgsTUVi2ghzq8wm27ud/mIM7AY2qEORR8Go3TVB4HzWQgp\n" +
                "  Zrt3i5MIlCaY504LzSRiigHCzAPlHws+W0rB5N+er5/2pJKnfBSDiCiFAVtCLOZ7\n" +
                "  gLiMm0jhO2B6tUXHI/+MRPjy02i59lINMRRev56GKtcd9qO/0kUJWdZTdA2XoS82\n" +
                "  ixPvZtXQpUpuL12ab+9EaDK8Z4RHJYYfCT3Q5vNAXaiWQ+8PTWm2QgBR/bkwSWc+\n" +
                "  NpUFgNPN9PvQi8WEg5UmAGMCAwEAAQ==\n"
        ).filterNot { it.isWhitespace() }

