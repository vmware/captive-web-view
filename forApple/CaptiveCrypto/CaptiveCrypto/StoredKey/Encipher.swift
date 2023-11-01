// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import CryptoKit

extension StoredKey {
    
    // Tuple for encrypted data and the algorithm. The algorithm is for
    // description only. It is nil in the symmetric key case.
    public struct Encrypted {
        let message:Data
        let algorithm:SecKeyAlgorithm?
    }


    // Instance methods.
    func encrypt(_ message:String) throws -> Encrypted
    {
        switch _storage {
        case .key:
            return try encryptBasedOnPrivateKey(message)
        case .generic:
            return try encryptWithSymmetricKey(message)
        }
    }

    private func encryptWithSymmetricKey(_ message:String) throws -> Encrypted {
        guard let box = try
            AES.GCM.seal(
                Data(message.utf8) as NSData, using: symmetricKey!
            ).combined else
        {
            throw StoredKeyError("Combined nil.")
        }
        return Encrypted(message:box, algorithm: nil)
    }

    // List of algorithms for public key encryption.
    static internal let algorithms:[SecKeyAlgorithm] = [
        .eciesEncryptionStandardX963SHA1AESGCM,
        .rsaEncryptionOAEPSHA512
    ]

    private func encryptBasedOnPrivateKey(_ message:String) throws -> Encrypted
    {
        guard let publicKey = SecKeyCopyPublicKey(secKey!) else {
            throw StoredKeyError("No public key.")
        }

        guard let algorithm = StoredKey.algorithms.first(
            where: { SecKeyIsAlgorithmSupported(publicKey, .encrypt, $0)}
            ) else
        {
            throw StoredKeyError("No algorithms supported.")
        }
        
        var error: Unmanaged<CFError>?
        guard let encryptedBytes = SecKeyCreateEncryptedData(
            publicKey, algorithm, Data(message.utf8) as CFData, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return Encrypted(message: encryptedBytes as Data, algorithm:algorithm)
    }
    
    // Static method that work with a key alias instead of a StoredKey
    // instance.
    static func encrypt(_ message:String, withFirstKeyNamed alias:String)
    throws -> Encrypted
    {
        guard let key = try keysWithName(alias).first else {
            throw StoredKeyError(errSecItemNotFound)
        }
        return try key.encrypt(message)
    }
    
}
