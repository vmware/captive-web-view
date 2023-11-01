// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

extension StoredKey {
    static func generateKeyPair(withName alias:String) throws -> KeyGeneration
    {
        // Official code snippets are here:
        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys
        
        let tagSD = StoredKey.tag(forAlias: alias)
        let attributes: [CFString: Any] = [
            // Next two lines are OK to create an RSA key.
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048,
            
            // Next two lines would be OK to create an elliptic curve key.
            // kSecAttrKeySizeInBits: 256,
            // kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
            
            // If you set an incompatible combination of bit size and type, you
            // get an OSstatus -50, which indicates that a parameter has an
            // invalid value.
            
            kSecPrivateKeyAttrs: [
                kSecAttrIsPermanent: true,
                kSecAttrLabel: alias,
                kSecAttrApplicationTag: tagSD.1
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateRandomKey(
            attributes as CFDictionary, &error) else
        {
            throw error!.takeRetainedValue() as Error
        }

        // Make a copy of the attributes dictionary except with a String for the
        // tag, instead of data, and with String keys instead of CFString.
        var returning = attributes
        returning[kSecPrivateKeyAttrs] = (
            attributes[kSecPrivateKeyAttrs] as! [CFString:Any])
            .merging([kSecAttrApplicationTag: tagSD.0]) {(_, new) in new}

        let summary = String(describing:secKey).split(separator: ",").map{
            String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // The String(describing:) in the above will return a value like this:
        //
        //     <SecKeyRef
        //         algorithm id: 1,
        //         key type: RSAPrivateKey,
        //         version: 4,
        //         block size: 2048 bits,
        //         addr: 0x280e3b560>
        //
        // (Split onto multiple lines here for readability.)
        //
        // That summary contains information that doesn't seem to be in the
        // attributes dictionary returned by:
        //
        //     SecKeyCopyAttributes(secKey)
        
        return KeyGeneration(
            deletedFirst: false,
            sentinelCheck: try generationSentinel(secKey, alias).rawValue,
            summary: summary,
            attributes:
                Description.normalise(cfAttributes: returning as CFDictionary)
        )
    }
    
    private static func tag(forAlias alias: String) -> (String, Data) {
        let tagString = "com.example.keys.\(alias)"
        return (tagString, tagString.data(using: .utf8)!)
    }

}
