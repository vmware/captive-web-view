// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import CryptoKit

extension StoredKey {
     
    static func keysWithName(_ alias:String) throws -> [StoredKey] {
        return try Storage.allCases.flatMap {storage -> [StoredKey] in
            var query: [CFString: Any] = [
                kSecClass: storage.secClass,
                kSecAttrLabel: alias,
                kSecMatchLimit: kSecMatchLimitAll
            ]
            
            switch(storage) {
            case .generic:
                query[kSecReturnData] = true
            case .key:
                query[kSecReturnRef] = true
            }
            
            var itemRef: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &itemRef)
            
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw StoredKeyError(status, "Query \(query).")
            }
            
            // Set items to an NSArray of the return value, or an empty NSArray.
            let items = status == errSecSuccess
                ? (itemRef as! CFArray) as NSArray
                : NSArray()
            
            return items.map({item in
                switch(storage) {
                case .generic:
                    return StoredKey(SymmetricKey(data: item as! Data))
                case .key:
                    return StoredKey(item as! SecKey)
                }
            })
        }
    }
    
}
