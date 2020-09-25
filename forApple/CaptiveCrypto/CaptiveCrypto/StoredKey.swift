// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

import CryptoKit

// General approach to storing symmetric keys in the keychain, and code
// snippets, are from here:
// https://developer.apple.com/documentation/cryptokit/storing_cryptokit_keys_in_the_keychain

// Declare protocol.
protocol GenericPasswordConvertible: CustomStringConvertible {
    /// Creates a key from a raw representation.
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes
    
    /// A raw representation of the key.
    var rawRepresentation: Data { get }
}

// Add extension that makes CryptoKey SymmetricKey satisfy the protocol.
extension SymmetricKey: GenericPasswordConvertible {
    public var description: String {
        return "symmetrically"
    }
    
    init<D>(rawRepresentation data: D) throws where D: ContiguousBytes {
        self.init(data: data)
    }
    
    var rawRepresentation: Data {
//        var body:Data
        return withUnsafeBytes{Data($0)}
//        return dataRepresentation  // Contiguous bytes repackaged as a Data instance.
    }
}
// End of first code to support storing CryptoKit symmetric key in the keychain.

// Handy extension to get an error message from an OSStatus.
extension OSStatus {
    var secErrorMessage: String {
        return (SecCopyErrorMessageString(self, nil) as String?) ?? "\(self)"
    }
}

extension NSNumber: Encodable {
    public func encode(to encoder: Encoder) throws {
        try Int(exactly: self).encode(to: encoder)
    }
}

extension CFNumber: Encodable {
    public func encode(to encoder: Encoder) throws {
//        var container = encoder.singleValueContainer()
//        try container.encode(Int(exactly: self as NSNumber))
//        try Int(exactly: self as NSNumber).encode(to: encoder)
        try (self as NSNumber).encode(to: encoder)
    }
}
extension CFString: Encodable {
    public func encode(to encoder: Encoder) throws {
        try (self as String).encode(to: encoder)
    }
}

//extension String: CodingKey {
//    public init?(intValue: Int) {
//        return nil
//    }
//
//    public init?(stringValue: String) {
//        self.init(stringValue)
//    }
//
//    public var intValue: Int? {
//        nil
//    }
//
//    public var stringValue: String {
//        self
//    }
//}

class StoredKey {
    enum Storage: String, CaseIterable {
        case generic, key

        var secClass:CFString {
            switch self {
            case .generic:
                return kSecClassGenericPassword
            case .key:
                return kSecClassKey
            }
        }
    }

    
    private enum KeyType: String, CaseIterable {
        case RSA, EC

        var secAttrKeyType:CFString {
            switch self {
            case .RSA:
                return kSecAttrKeyTypeRSA
            case .EC:
                return kSecAttrKeyTypeECSECPrimeRandom
            }
        }
        // There is also a kSecAttrKeyTypeEC, which is deprecated. It has the
        // same value as kSecAttrKeyTypeECSECPrimeRandom. This means that
        // there's no way to tell the difference by matching.

        static func matching(_ secAttrKeyTypeValue:CFString) -> KeyType? {
            Self.allCases.first(where: {
                $0.secAttrKeyType == secAttrKeyTypeValue
            })
        }
        
        struct Description<RAW:Encodable>:Encodable {
            let keyType:String
            let raw:RAW // Raw

//            enum Raw:Encodable {
//                case cfString(CFString)
//                case cfNumber(CFNumber)
//
//                func encode(to encoder: Encoder) throws {
////                    var container = encoder.singleValueContainer()
//                    switch self {
//                    case .cfNumber(let raw):
//                        try raw.encode(to: encoder)
////                        try container.encode(Int(exactly: raw as NSNumber))
//                    case .cfString(let raw):
//                        try (raw as String).encode(to: encoder)
////                        try container.encode(raw as String)
//                    }
//                }
//            }

//            init(keyType:String, raw:Raw) {
//                self.keyType = keyType
//                self.raw = raw
//            }
            init<ENCODABLE:Encodable>(keyType:String, raw:ENCODABLE) {
                self.keyType = keyType
                self.raw = raw as! RAW // Raw.cfString(raw)
            }
//            init<CFNumber(keyType:String, raw:CFNumber) {
//                self.keyType = keyType
//                self.raw = Raw.cfNumber(raw)
//            }
            
            static func ifCFNumber(_ specifier: Any)
            -> KeyType.Description<CFNumber>?
            {
                // If the specifier is a number, compare to the numbers in each
                // kSecAttrKeyType constant.
                if let typeNumber = specifier as? NSNumber,
                   let typeInt = Int(exactly: typeNumber),
                   let keyType = KeyType.allCases.first(where: {
                    Int($0.secAttrKeyType as String) == typeInt
                   })
                {
                    return KeyType.Description.init(
                        keyType: keyType.rawValue, raw: typeNumber as CFNumber)
                }
                else {
                    return nil
                }
            }

            static func asCFString(_ specifier: Any) -> Self<CFString> {
                if let typeString = specifier as? String {
                    return Self.init(
                        keyType:
                            KeyType.matching(typeString as CFString)?.rawValue
                            ?? typeString,
                        raw: typeString as CFString
                    )
                }
                
                return Self.init(
                    keyType: "\(specifier)",
                    raw: "\(specifier)" as CFString
                )
            }
            
            static func describe(_ specifier:Any, into destination: inout Any) {
                if let description = ifCFNumber(specifier) {
                    destination = description
                }
                else {
                    destination = asCFString(specifier)
                }
            }

            init(fromCopyAttribute specifier: Any) {
//                var keyType:String?
//                var raw:Raw?

                // The values for the key type attribute, kSecAttrKeyType, have slightly
                // strange behaviour.
                //
                // In the dictionary passed to SecKeyCreateRandomKey, the value of the
                // kSecAttrKeyType attribute is a CFString. However, the contents of the
                // CFString will be numeric. For example, kSecAttrKeyTypeRSA has the
                // value "42". See, for example:
                // https://opensource.apple.com/source/Security/Security-55471/sec/Security/SecItemConstants.c.auto.html
                //
                // In the dictionary returned from SecItemCopyMatching, the value of the
                // kSecAttrKeyType attribute will be a CFNumber.

                // If the specifier is a number, compare to the numbers in each
                // kSecAttrKeyType constant.
                if let typeNumber = specifier as? NSNumber,
                   let typeInt = Int(exactly: typeNumber),
                   let keyType = KeyType.allCases.first(where: {
                    Int($0.secAttrKeyType as String) == typeInt
                   })
                {
                    self.init(keyType: keyType.rawValue, raw: typeNumber as CFNumber)
                    return
                    
//                        ?.rawValue
//                    raw = .cfNumber(typeNumber)
                }

                // If the specifier isn't a number, or didn't match, try it as a string
                // instead.
//                if keyType == nil, let typeString = specifier as? String {
                if let typeString = specifier as? String {
                    self.init(
                        keyType:
                            KeyType.matching(typeString as CFString)?.rawValue
                            ?? typeString,
                        raw: typeString as CFString
                    )
                    return
                }
                
                self.init(
                    keyType: "\(specifier)",
                    raw: "\(specifier)" as CFString
                )

                
//                self.init(keyType: keyType!, raw: raw!)
            }
        }
        
        static func describe(_ specifier:Any) -> Encodable {
            if let description = KeyType.Description<CFNumber>
                .ifCFNumber(specifier)
            {
                return description
            }
            else {
                return KeyType.Description<CFString>
                    .asCFString(specifier)
            }

        }
    }

    static func deleteAll() -> (deleted:[String], notDeleted:[String:String]) {
        var deleted:[String] = []
        var notDeleted:[String:String] = [:]
        
        for storage in Storage.allCases {
            // Query to find all items of this security class.
            let query: [CFString: Any] = [kSecClass: storage.secClass]
            let status = SecItemDelete(query as CFDictionary)
            if status == errSecSuccess || status == errSecItemNotFound {
                deleted.append(storage.rawValue)
            }
            else {
                notDeleted[storage.rawValue] = status.secErrorMessage
            }
        }
        
        return (deleted:deleted, notDeleted:notDeleted)
    }
    
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
                    return StoredKey(item as! Data)
                case .key:
                    return StoredKey(item as! SecKey)
                }
            })
        }
    }
    
    public struct Encrypted {
        let message:Data
        let algorithm:SecKeyAlgorithm?
    }

    static func encrypt(_ message:String, withFirstKeyNamed alias:String)
    throws -> Encrypted
    {
        guard let key = try keysWithName(alias).first else {
            throw StoredKeyError(errSecItemNotFound)
        }
        return try key.encrypt(message)
    }
    
    static func decrypt(_ encrypted:Encrypted, withFirstKeyNamed alias:String)
    throws -> String
    {
        guard let key = try keysWithName(alias).first else {
            throw StoredKeyError(errSecItemNotFound)
        }
        return try key.decrypt(encrypted)
    }
    
    struct EncodableElement:Encodable {
        let encodable:Encodable
        
        init(_ encodable:Encodable) {
            self.encodable = encodable
        }

        func encode(to encoder: Encoder) throws {
            try encodable.encode(to: encoder)
        }
    }
    
//    enum EncodableElement:Encodable {
////        case int(Int)
////        case string(String)
////        case dictionary([String:AttributeValue])
//        case encodable(Encodable)
//
//        func encode(to encoder: Encoder) throws {
//            switch self {
////            case .int(let int):
////                try int.encode(to: encoder)
////            case .dictionary(let dictionary):
////                try dictionary.encode(to: encoder)
////            case .string(let string):
////                try string.encode(to: encoder)
//            case .encodable(let encodable):
//                try encodable.encode(to: encoder)
//            }
//        }
//    }
    
    public struct Description:Encodable {
        let storage:String
        let name:String
        let type:String
        let attributes:[String:EncodableElement]
        
        init(_ storage:Storage, _ attributes:CFDictionary) {
            self.storage = storage.rawValue
            self.attributes = Description.normalise(cfAttributes: attributes)
            self.name =
                (attributes as NSDictionary)[kSecAttrLabel as String] as? String ?? ""
            let keyType:String
            if let element = self.attributes[kSecAttrKeyType as String] {
               if let keyDescription = element.encodable
                    as? KeyType.Description<CFNumber>
               {
                keyType = keyDescription.keyType
               }
               else if let keyDescription = element.encodable as?
                        KeyType.Description<CFString>
               {
                keyType = keyDescription.keyType
               }
               else {
                keyType = ""
               }
            }
            else {
                keyType = ""
            }
            
//                (
//            switch self.attributes[kSecAttrKeyType as String] {
//            case .encodable(let encodable):
//                if let keyDescription =
//                    encodable as? KeyType.Description<CFNumber>
//                {
//                    keyType = keyDescription.keyType
//                }
//                else if let keyDescription =
//                            encodable as? KeyType.Description<CFString>
//                {
//                    keyType = keyDescription.keyType
//                }
//                else {
//                    keyType = ""
//                }
//            default:
//                keyType = ""
//            }
            self.type = keyType
//                (keyDescription as? KeyType.Description<CFNumber>)?.keyType
//                ?? (keyDescription as? KeyType.Description<CFString>)?.keyType
//                ?? ""
        }

//        enum CodingKeys: String, CodingKey {
//            case storage
//            case name
//            case type
//            case attributes
//        }
//
//        public func encode(to encoder: Encoder) throws {
//            var container = encoder.container(keyedBy: CodingKeys.self)
//            try container.encode(storage, forKey: .storage)
//            try container.encode(name, forKey: .name)
//
//            try attributes.encode(to: encoder)
//
////            var attributesContainer = container.nestedContainer(
////                keyedBy: String.self, forKey: .attributes)
////            try attributes.forEach {
////                var elementContainer = encoder.singleValueContainer()
////                elementContainer.encode($1)
////                attributesContainer.encode($1, forKey: $0)
////            }
//
//        }

        static func normalise(cfAttributes:CFDictionary) -> [String:EncodableElement] {
            // Keys in the returned dictionary will sometimes be the short names
            // that are the underlying values of the various kSecAttr constants. You
            // can see a list of all the short names and corresponding kSecAttr
            // names in the Apple Open Source SecItemConstants.c file. For example,
            // here:
            // https://opensource.apple.com/source/Security/Security-55471/sec/Security/SecItemConstants.c.auto.html
            
            var returning: Dictionary<String, EncodableElement> = [:]
            for (rawKey, rawValue) in cfAttributes as NSDictionary {
                let value:Encodable = rawValue as? NSNumber ??
                    (rawValue as? Encodable ?? "\(rawValue)")
                
            
                
                //                let value:Any = rawValue as? NSNumber ?? (
//                    JSONSerialization.isValidJSONObject(rawValue)
//                        ? rawValue : "\(rawValue)"
//                )
                
                if let key = rawKey as? String {
                    if key == kSecAttrApplicationTag as String {
                        let cfValue = rawValue as! CFData
                        returning[key] = EncodableElement(
                            String(data: cfValue as Data, encoding: .utf8)
                                ?? "\(cfValue)"
                        )
                    }
                    else if key == kSecAttrKeyType as String {
                        returning[key] = EncodableElement(KeyType.describe(rawValue))
                    }
                    else {
                        returning[key] = EncodableElement(value) //(value as! Encodable)
                    }
                }
                else {
                    returning[String(describing: rawKey)] =
                        EncodableElement(value)
//                        (value as! Encodable)
                }
            }
            return returning
        }
        
    }

    static func describeAll() throws -> [Description] {
        return try Storage.allCases.flatMap {storage -> [Description] in
            let query: [CFString: Any] = [
                kSecClass: storage.secClass,
                kSecReturnAttributes: true,
                kSecMatchLimit: kSecMatchLimitAll
            ]
            // Above query sets kSecMatchLimit: kSecMatchLimitAll so that the
            // results will be a CFArray the type of each item in the array is
            // determined by which kSecReturn option is set.
            //
            // kSecReturnAttributes true
            // Gets a CFDictionary representation of each key.
            //
            // kSecReturnRef true
            // Gets a SecKey object for each key. A dictionary representation can be
            // generated from a SecKey by calling SecKeyCopyAttributes(), which is
            // done in the summarise(key:) method, below. However the resulting
            // dictionary has only a subset of the attributes. For example, it
            // doesn't have these:
            //
            // -   kSecAttrLabel
            // -   kSecAttrApplicationTag
            //
            // kSecReturnData true
            // Gets a CFData instance for each key. From the reference documentation
            // it looks like the data should be a PKCS#1 representation.
            
            var itemRef: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &itemRef)
            
            // If SecItemCopyMatching failed, status will be a numeric error code.
            // To find out what a particular number means, you can look it up here:
            // https://www.osstatus.com/search/results?platform=all&framework=all&search=errSec
            // That will get you the symbolic name.
            //
            // Symbolic names can be looked up in the official reference, here:
            // https://developer.apple.com/documentation/security/1542001-security_framework_result_codes
            // But it isn't searchable by number.
            //
            // This is how Jim found out that -25300 is errSecItemNotFound.
            
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw StoredKeyError(status)
            }
            
            // Set items to an NSArray of the return value, or an empty NSArray.
            let items = status == errSecSuccess
                ? (itemRef as! CFArray) as NSArray
                : NSArray()
            
            return items.map { item -> Description in
                Description(storage, item as! CFDictionary)
//                let attributes = summarise(cfDictionary: item as! CFDictionary)
//                Description(
//                    keyType: storage.rawValue,
//                    name: attributes[kSecAttrLabel as String] ?? "",
//                    type: (
//                        attributes[kSecAttrKeyType as String] as? [String:Any]
//                        )?[KEY.key] ?? "",
//
//                    attributes: attributes)
            }

                // If using kSecReturnRef true, uncomment this code.
                // store.append(self.summarise(key: item as! SecKey))
                //
                // If using kSecReturnData true, uncomment this code.
                // let cfData = item as! CFData
                // store.append(["data":"\(cfData)"])
        }
    }
        
    struct KeyGeneration {
        let deletedFirst:Bool
        let attributes:[String:Any]
    }
    
    static func generateKey(withName alias:String) throws -> KeyGeneration {
        // First delete any generic key chain item with the same label. If you
        // don't, the add seems to fail as a duplicate.
        let deleteQuery:[CFString:Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrLabel: alias,
            
            // Generic passwords in the keychain use the following two items as
            // identifying attributes. If you don't set them, a first keychain
            // item will still be stored, but a second keychain item will be
            // rejected as a duplicate.
            // TOTH: https://useyourloaf.com/blog/keychain-duplicate-item-when-adding-password/
            kSecAttrAccount: "Account \(alias)",
            kSecAttrService: "Service \(alias)"
            
        ]
        let deleted = SecItemDelete(deleteQuery as CFDictionary)
        guard deleted == errSecSuccess || deleted == errSecItemNotFound else {
            throw StoredKeyError(
                deleted, "Failed SecItemDelete(\(deleteQuery)).")
        }

        let key = SymmetricKey(size: .bits256)
        
        // Merge in more query attributes, to create the add query.
        let addQuery = deleteQuery.merging([
            kSecReturnAttributes: true,
            kSecValueData: key.rawRepresentation,
        ]) {(_, new) in new}

        var result: CFTypeRef?
        let added = SecItemAdd(addQuery as CFDictionary, &result)
        guard added == errSecSuccess else {
            throw StoredKeyError(added, "Failed SecItemAdd(\(addQuery),)")
        }

        return KeyGeneration(
            deletedFirst: deleted == errSecSuccess,
            attributes:
                Description.normalise(cfAttributes: result as! CFDictionary)
        )
    }

    
    private static func tag(forAlias alias: String) -> (String, Data) {
        let tagString = "com.example.keys.\(alias)"
        return (tagString, tagString.data(using: .utf8)!)
    }

    static func generateKeyPair(withName alias:String) throws -> KeyGeneration
    {
        // Code snippets are here:
        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys
        
        let tagSD = StoredKey.tag(forAlias: alias)
        let attributes: [CFString: Any] = [

            // Next two lines are OK to create an RSA key.
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2048,
            
            // Next two lines are OK to create an elliptic curve key.
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
        guard let _ = SecKeyCreateRandomKey(
            attributes as CFDictionary, &error) else
        {
            throw error!.takeRetainedValue() as Error
        }
        
        // Make a copy of the attributes dictionary except with values that are:
        // -   Serialisable to JSON.
        // -   Descriptive instead of numeric.
        var returning = attributes
        returning[kSecAttrKeyType] =
            KeyType.describe(returning[kSecAttrKeyType]!)
        returning[kSecPrivateKeyAttrs] = (
            attributes[kSecPrivateKeyAttrs] as! [CFString:Any])
            .merging([kSecAttrApplicationTag: tagSD.0]) {(_, new) in new}
            .withStringKeys()
        return KeyGeneration(
            deletedFirst: false, attributes: returning.withStringKeys())

//        return [
//            .sentinel: try encrypt(
//                sentinel: "Centennial", basedOnPrivateKey: privateKey
//            ).withStringKeys(),
//            .attributes: returning.withStringKeys(),
//            .key: self.summarise(key:privateKey).withStringKeys()
//        ]
    }
    
    private let storage:Storage
    let secKey:SecKey?
    let keyData:Data?
    
    init(_ secKey:SecKey) {
        storage = .key
        self.secKey = secKey
        keyData = nil
    }
    
    init(_ keyData:Data) {
        storage = .generic
        secKey = nil
        self.keyData = keyData
    }
    
    private let algorithms = [
        SecKeyAlgorithm.eciesEncryptionStandardX963SHA1AESGCM,
        SecKeyAlgorithm.rsaEncryptionOAEPSHA512
    ]
    func encrypt(_ message:String) throws -> Encrypted
    {
        switch storage {
        case .key:
            return try encryptBasedOnPrivateKey(message)
        case .generic:
            return try encryptWithSymmetricKey(message)
        }
    }

    func decrypt(_ encrypted:Data) throws -> String {
        switch storage {
        case .key:
            return try decryptWithPrivateKey(encrypted as CFData)
        case .generic:
            return try decryptWithSymmetricKey(encrypted)
        }
    }
    func decrypt(_ encrypted:Encrypted) throws -> String {
        return try decrypt(encrypted.message)
    }

    private func encryptBasedOnPrivateKey(_ message:String) throws -> Encrypted
    {
        guard let publicKey = SecKeyCopyPublicKey(secKey!) else {
            throw StoredKeyError("No public key.")
        }

        guard let algorithm = algorithms.first(
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
    
    private func decryptWithPrivateKey(_ encrypted:CFData) throws -> String {
        guard let publicKey = SecKeyCopyPublicKey(secKey!) else {
            throw StoredKeyError("No public key.")
        }
        guard let algorithm = algorithms.first(
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
    
    private func encryptWithSymmetricKey(_ message:String) throws -> Encrypted {
        let key = try SymmetricKey(rawRepresentation:keyData!)
        guard let box = try
            AES.GCM.seal(Data(message.utf8) as NSData, using: key).combined
            else
        {
            throw StoredKeyError("Combined nil.")
        }
        return Encrypted(message:box, algorithm: nil)
    }

    private func decryptWithSymmetricKey(_ encrypted:Data) throws -> String {
        let sealed = try AES.GCM.SealedBox(combined: encrypted)
        let key = try SymmetricKey(rawRepresentation:keyData!)
        let decryptedData = try AES.GCM.open(sealed, using: key)
        let message =
            String(data: decryptedData, encoding: .utf8) ?? "\(decryptedData)"
        return message
    }

}

extension Array {
    func inserting(_ element:Element, at index:Int) -> Array<Element> {
        var inserted = self
        inserted.insert(element, at: index)
        return inserted
    }
}

// Swift seems to have made it rather difficult to create a throw-able that
// has a message that can be retrieved in the catch. So, there's a custom
// class here.
//
// Having created a custom class anyway, it seemed like a code-saver to pack
// it with convenience initialisers for an array of strings, variadic
// strings, and CFString.

public class StoredKeyError: Error, CustomStringConvertible {
    let _message:String
    
    public init(_ message:String) {
        self._message = message
    }
    public convenience init(_ message:[String]) {
        self.init(message.joined())
    }
    public convenience init(_ message:String...) {
        self.init(message)
    }
    public convenience init(_ message:CFString) {
        self.init(NSString(string: message) as String)
    }
    public convenience init(_ osStatus:OSStatus, _ details:String...) {
        self.init(details.inserting(osStatus.secErrorMessage, at: 0))
    }

    public var message: String {
        return self._message
    }
    
    public var localizedDescription: String {
        return self._message
    }
    
    public var description: String {
        return self._message
    }
}
