// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import CryptoKit

extension StoredKey {
    // Instance methods.
    func decrypt(_ encrypted:Data) throws -> String {
        switch _storage {
        case .key:
            return try decryptWithPrivateKey(encrypted as CFData)
        case .generic:
            return try decryptWithSymmetricKey(encrypted)
        }
    }
    func decrypt(_ encrypted:Encrypted) throws -> String {
        return try decrypt(encrypted.message)
    }
    
    private func decryptWithSymmetricKey(_ encrypted:Data) throws -> String {
        let sealed = try AES.GCM.SealedBox(combined: encrypted)
        let decryptedData = try AES.GCM.open(sealed, using: symmetricKey!)
        let message =
            String(data: decryptedData, encoding: .utf8) ?? "\(decryptedData)"
        return message
    }


    private func decryptWithPrivateKey(_ encrypted:CFData) throws -> String {
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
        guard let decryptedBytes = SecKeyCreateDecryptedData(
            secKey!, algorithm, encrypted, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        let message = String(
            data: decryptedBytes as Data, encoding: .utf8)
            ?? "\(decryptedBytes)"
        return message
    }

    // Static methods that work with a key alias instead of a StoredKey
    // instance.
    static func decrypt(_ encrypted:Encrypted, withFirstKeyNamed alias:String)
    throws -> String
    {
        guard let key = try keysWithName(alias).first else {
            throw StoredKeyError(errSecItemNotFound)
        }
        return try key.decrypt(encrypted)
    }
}
