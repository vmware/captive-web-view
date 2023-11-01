// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

extension StoredKey {
    public enum GenerationSentinelResult:String {
        case passed, failed, multipleKeys
    }
    
    internal static func generationSentinel(
        _ basis:StoredKeyBasis, _ alias:String
    ) throws -> GenerationSentinelResult
    {
        let keys = try self.keysWithName(alias)
        if keys.count == 1 {
            let storedKey = basis.storedKey()
            let sentinel = "InMemorySentinel"
            let encrypted = try storedKey.encrypt(sentinel)
            let decrypted = try self.decrypt(
                encrypted, withFirstKeyNamed: alias)
            return sentinel == decrypted ? .passed : .failed
        }
        else {
            return .multipleKeys
        }
    }
    
    struct KeyGeneration:Encodable {
        let deletedFirst:Bool
        let sentinelCheck:String
        let summary:[String]
        let attributes:[String:AnyEncodable]
    }
}
