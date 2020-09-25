// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import CaptiveWebView

import CryptoKit

// Convenience extension to facilitate use of the KEY enumeration as keys in a
// dictionary.
extension Dictionary where Key == String {
    subscript(_ key:MainViewController.KEY) -> Value? {
        get {
            return self[key.rawValue]
        }
    }

    // Following was intended as a way to use a dictionary literal in which the
    // keys are KEY as a dictionary with String keys. It doesn't work, although
    // it does compile.
//    init(dictionaryLiteral elements: (MainViewController.KEY, Value)...) {
//        let values = elements.map {
//            (key, value) in
//            return (key.rawValue, value)
//        }
//        self.init(uniqueKeysWithValues: values)
//    }
}

// Clunky but can be used to create a dictionary with String keys from a
// dictionary literal with KEY keys.
extension Dictionary where Key == MainViewController.KEY {
    func withStringKeys() -> [String: Value] {
        return Dictionary<String, Value>(uniqueKeysWithValues: self.map {
            ($0.rawValue, $1)
        })
    }
}

extension Dictionary where Key == CFString {
    func withStringKeys() -> [String: Value] {
        return Dictionary<String, Value>(uniqueKeysWithValues: self.map {
            ($0 as String, $1)
        })
    }
}

class FancyDateFormatter {
    private static let formats = ["dd", "MMM", "yyyy HH:mm z"]
    private static let formatters: [DateFormatter] = { formats.map {
        let formatter = DateFormatter()
        formatter.dateFormat = $0
        return formatter
    } }()
    
    private init() {}
    
    static func string(from date:Date) -> String {
        let formatted = formatters.map{ $0.string(from: date) }
        return [
            formatted[0], formatted[1].lowercased(), formatted[2]
        ].joined()
    }
}


class MainViewController: CaptiveWebView.DefaultViewController {
    
    // Implicit raw values, see:
    // https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html#ID535
    private enum Command: String {
        case capabilities, deleteAll, encrypt, summariseStore,
             generateKey, generatePair
    }
    
    public enum KEY: String {
        case deleted, notDeleted,

             alias, attributes, parameters, items, count, summary,
             key, keyStore,
             
             sentinel, encryptedSentinel, decryptedSentinel, passed, algorithm,
             
             stored, deletedFirst,
             
             raw, store, name, type,
             
             secureEnclave, date
    }
    
    override func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any>
    {
        switch Command(rawValue: command) {
        
        case .capabilities:
            return summariseCapabilities().withStringKeys()
            
        case .deleteAll:
            let tuple = StoredKey.deleteAll()
            return [
                KEY.deleted: tuple.deleted, KEY.notDeleted: tuple.notDeleted
            ].withStringKeys()
            
        case .encrypt:
            guard let parameters = commandDictionary[KEY.parameters]
                    as? Dictionary<String, Any> else
            {
                throw CaptiveWebView.ErrorMessage(
                    "Command `", Command.encrypt.rawValue, "` requires `"
                    , KEY.parameters.rawValue, "`.")
            }
            guard let alias = parameters[KEY.alias] as? String else {
                throw CaptiveWebView.ErrorMessage(
                    "Command `", Command.encrypt.rawValue, "` requires `"
                    , KEY.parameters.rawValue, "` with `", KEY.alias.rawValue
                    , "`.")
            }
            guard let sentinel = parameters[KEY.sentinel] as? String else {
                throw CaptiveWebView.ErrorMessage(
                    "Command `", Command.encrypt.rawValue, "` requires `"
                    , KEY.parameters.rawValue, "` with `", KEY.sentinel.rawValue
                    , "`.")
            }
            return try [
                "testResults": testKey(alias: alias, sentinel: sentinel)]

        case .summariseStore:
            let returning = [KEY.keyStore:try StoredKey.describeAll()].withStringKeys()
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(returning),
               let json = try JSONSerialization.jsonObject(
                with: encoded, options: []) as? Dictionary<String, Any>
            {
                return json
            }
            return returning
//                        try summariseStore()].withStringKeys()
            
        case .generateKey:
            guard
                let parameters = commandDictionary[KEY.parameters]
                    as? Dictionary<String, Any>,
                let alias = parameters[KEY.alias] as? String
            else {
                throw CaptiveWebView.ErrorMessage(
                    "Key `", KEY.alias.rawValue,
                    "` must be specified in `", KEY.parameters.rawValue, "`.")
            }
            return ["results": try StoredKey.generateKey(withName: alias)]
//            return try generateKey(alias).withStringKeys()

        case .generatePair:
            guard
                let parameters = commandDictionary[KEY.parameters]
                    as? Dictionary<String, Any>,
                let alias = parameters[KEY.alias] as? String
            else {
                throw CaptiveWebView.ErrorMessage(
                    "Key `", KEY.alias.rawValue,
                    "` must be specified in `", KEY.parameters.rawValue, "`.")
            }
            return ["results": try StoredKey.generateKeyPair(withName: alias)]
//            return try generateKeyPair(alias).withStringKeys()

        default:
            return try super.response(to: command, in: commandDictionary)
        }
    }
    
    private func summariseCapabilities() -> [KEY:Any] {
        return [
            .secureEnclave: SecureEnclave.isAvailable,
            .date: FancyDateFormatter.string(from: Date())
        ]
    }
    
//    private func clearStore() throws -> [String:Any] {
//        var deleted:[String:Any] = [:]
//        try self.eachSecClass {selector, label in
//            // Query to find all items of this security class.
//            let query: [CFString: Any] = [kSecClass: selector]
//            let status = SecItemDelete(query as CFDictionary)
//            if let rhs:Any = status == errSecSuccess ? true
//                : status == errSecItemNotFound ? false : nil
//            {
//                return [[label:rhs]]
//            }
//            if let rhs = status.secErrorMessage {
//                return [[label:rhs]]
//            }
//            throw osStatusError(status)
//        }.forEach {
//            deleted.merge($0, uniquingKeysWith: {(_, new) in new})
//        }
//        return [KEY.deleted: deleted].withStringKeys()
//    }
//
//    private func eachSecClass<T>(_ oneSecClass:
//        (_ selector: CFString, _ label: String) throws -> [T]
//    ) rethrows -> [T]
//    {
//        return try [kSecClassGenericPassword, kSecClassKey].flatMap {
//            try oneSecClass(
//                $0,
//                $0 == kSecClassKey ? "key" :
//                    $0 == kSecClassGenericPassword ? "generic" :
//                    $0 as String
//            )
//        }
//    }

//    private func osStatusError(_ preamble:String?, _ osStatus: OSStatus) -> Error
//    {
//        // Plan A: use the proper method to create an error message.
//        if let message = osStatus.secErrorMessage {
//            // The reference for SecCopyErrorMessageString is here:
//            // https://developer.apple.com/documentation/security/1394686-seccopyerrormessagestring
//            //
//            // It says: "Call the CFRelease function to release this object
//            // when you are finished using it." Presume like this:
//            // CFRelease(message)
//            //
//            // However, if you do then Xcode flags an error:
//            // 'CFRelease' is unavailable: Core Foundation objects are
//            // automatically memory managed
//            //
//            // It also says to pass NULL as the second parameter, which
//            // isn't accepted by the compiler. This code passes nil instead.
//
//            return preamble == nil
//                ? CaptiveWebView.ErrorMessage(message as String)
//                : CaptiveWebView.ErrorMessage(preamble!, " ", message as String)
//        }
//
//        // Plan B: create an NSError instead.
//        return preamble == nil
//            ? NSError(domain: NSOSStatusErrorDomain, code: Int(osStatus))
//            : NSError(domain: NSOSStatusErrorDomain, code: Int(osStatus),
//                      userInfo: ["information":preamble!])
//    }
//    private func osStatusError(_ osStatus: OSStatus) -> Error {
//        return osStatusError(nil, osStatus)
//    }
    
    private func testKey(alias: String, sentinel: String)
    throws -> [[String:Any]]
    {
        var results: [[String:Any]] = []

        let keys = try StoredKey.keysWithName(alias)
        guard keys.count == 1 else {
            if keys.count <= 0 {
                results.append([
                    "failed": [
                        "reason": "No key found for alias", "alias": alias
                    ]
                ])
            }
            
            if keys.count > 1 {
                results.append([
                    "failed": [
                        "reason": "Too many keys found for alias",
                        "alias": alias,
                        "count": keys.count
                    ]
                ])
            }
            
            return results
        }

        results.append(["key": "\(keys.first)" as Any])
        
        let encrypted:StoredKey.Encrypted
        do {
//            encrypted = try key!.encrypt(sentinel)
            encrypted = try StoredKey.encrypt(
                sentinel, withFirstKeyNamed: alias)
            results.append([
                KEY.encryptedSentinel: String(describing: encrypted.message),
                KEY.algorithm: encrypted.algorithm?.rawValue as Any
            ].withStringKeys())
        }
        catch let error as StoredKeyError {
            results.append(["failed":error.localizedDescription])
            return results
        }
        catch {
            results.append(["failed":error.localizedDescription])
            return results
        }

        let decrypted:String
        do {
            decrypted = try StoredKey.decrypt(
                encrypted, withFirstKeyNamed: alias)
//                key!.decrypt(encrypted.message)
            results.append([
                KEY.decryptedSentinel: decrypted,
                KEY.passed: decrypted == sentinel,
            ].withStringKeys())
        }
        catch let error as StoredKeyError {
            results.append(["failed":error.localizedDescription])
            return results
        }
        catch {
            results.append(["failed":error.localizedDescription])
            return results
        }

        return results
    }
    
//    private func keyWith(alias:String)
//    throws -> (key:StoredKey?, error:[String: Any]?)
//    {
//        let keys:[StoredKey] = try self.eachSecClass {selector, label in
//            var query: [CFString: Any] = [
//                kSecClass: selector,
//                kSecAttrLabel: alias,
//                kSecMatchLimit: kSecMatchLimitAll
//            ]
//
//            switch(selector) {
//            case kSecClassKey:
//                query[kSecReturnRef] = true
//            case kSecClassGenericPassword:
//                query[kSecReturnData] = true
//            default:
//                break
//            }
//
//            var itemRef: CFTypeRef?
//            let status = SecItemCopyMatching(query as CFDictionary, &itemRef)
//
//            guard status == errSecSuccess || status == errSecItemNotFound else {
//                throw self.osStatusError("Query \(query).", status)
//            }
//
//            // Set items to an NSArray of the return value, or an empty NSArray.
//            let items = status == errSecSuccess
//                ? (itemRef as! CFArray) as NSArray
//                : NSArray()
//
//            let retItems:[StoredKey] = items.compactMap {item in
//                switch(selector) {
//                case kSecClassKey:
//                    return StoredKey(item as! SecKey)
//                case kSecClassGenericPassword:
//                    return StoredKey(item as! Data)
//                default:
//                    return nil
//                }
//            }
//
////            var
////            items.enumerateObjects {
////                (item: Any, index: Int, stop: UnsafeMutablePointer<ObjCBool>) in
////
////            }
//
//            return retItems// as [CFTypeRef]
//        }// as (_ selector: CFString, _ label: String) throws -> [Any])
//
//        if keys.count <= 0 { return (
//            nil, ["reason": "No key found for alias", "alias": alias]
//        ) }
//
//        if keys.count > 1 { return (
//            nil, [
//                "reason": "Too many keys found for alias",
//                "alias": alias,
//                "count": keys.count
//            ]
//        ) }
//
//        return (keys.first, nil)
//    }

//    private func summariseStore() throws -> [[String: Any]] {
//        return try self.eachSecClass {selector, label in
//            let query: [CFString: Any] = [
//                kSecClass: selector,
//                kSecReturnAttributes: true,
//                kSecMatchLimit: kSecMatchLimitAll
//            ]
//            // Above query sets kSecMatchLimit: kSecMatchLimitAll so that the
//            // results will be a CFArray the type of each item in the array is
//            // determined by which kSecReturn option is set.
//            //
//            // kSecReturnAttributes true
//            // Gets a CFDictionary representation of each key.
//            //
//            // kSecReturnRef true
//            // Gets a SecKey object for each key. A dictionary representation can be
//            // generated from a SecKey by calling SecKeyCopyAttributes(), which is
//            // done in the summarise(key:) method, below. However the resulting
//            // dictionary has only a subset of the attributes. For example, it
//            // doesn't have these:
//            //
//            // -   kSecAttrLabel
//            // -   kSecAttrApplicationTag
//            //
//            // kSecReturnData true
//            // Gets a CFData instance for each key. From the reference documentation
//            // it looks like the data should be a PKCS#1 representation.
//
//            var itemRef: CFTypeRef?
//            let status = SecItemCopyMatching(query as CFDictionary, &itemRef)
//
//            // Set items to an NSArray of the return value, or an empty NSArray.
//            let items = status == errSecSuccess
//                ? (itemRef as! CFArray) as NSArray
//                : NSArray()
//
//            // If SecItemCopyMatching failed, status will be a numeric error code.
//            // To find out what a particular number means, you can look it up here:
//            // https://www.osstatus.com/search/results?platform=all&framework=all&search=errSec
//            // That will get you the symbolic name.
//            //
//            // Symbolic names can be looked up in the official reference, here:
//            // https://developer.apple.com/documentation/security/1542001-security_framework_result_codes
//            // But it isn't searchable by number.
//            //
//            // This is how Jim found out that -25300 is errSecItemNotFound.
//
//            guard status == errSecSuccess || status == errSecItemNotFound else {
//                throw osStatusError(status)
//            }
//
//            var store:[[String:Any]] = []
//
//            // In case of errSecItemNotFound, items will be an empty array.
//            items.enumerateObjects {
//                (item: Any, index: Int, stop: UnsafeMutablePointer<ObjCBool>) in
//                let summary = self.summarise(cfDictionary: item as! CFDictionary)
//                // If using kSecReturnAttributes true, uncomment this code.
//                store.append([
//                    KEY.store: label, KEY.summary: summary,
//                    KEY.name: summary[kSecAttrLabel as String] ?? "",
//                    KEY.type: (
//                        summary[kSecAttrKeyType as String] as? [String:Any]
//                        )?[KEY.key] ?? ""
//                ].withStringKeys())
//
//                // If using kSecReturnRef true, uncomment this code.
//                // store.append(self.summarise(key: item as! SecKey))
//                //
//                // If using kSecReturnData true, uncomment this code.
//                // let cfData = item as! CFData
//                // store.append(["data":"\(cfData)"])
//            }
//
//            return store
//        }
//    }
//
//    private func summarise(key secKey: SecKey) -> Dictionary<KEY, Any> {
//        var attributes: Dictionary<String, Any>? = nil
//        if let copyAttributes = SecKeyCopyAttributes(secKey) {
//            attributes = self.summarise(cfDictionary: copyAttributes)
//        }
//
//        return [.summary: "\(secKey)".split(separator: ","),
//                .attributes: attributes ?? "null"]
//    }

//    private func generateKey(_ alias:String) throws -> Dictionary<KEY, Any> {
//        let key = SymmetricKey(size: .bits256)
//        let sentinel = "Sentinel"
//        guard let box = try
//            AES.GCM.seal(Data(sentinel.utf8) as NSData, using: key).combined
//            else
//        {
//            throw CaptiveWebView.ErrorMessage("Combined nil.")
//        }
//        
//        let sealed = try AES.GCM.SealedBox(combined: box)
//        let decryptedData = try AES.GCM.open(sealed, using: key)
//        let decryptedSentinel =
//            String(data: decryptedData, encoding: .utf8) ?? "\(decryptedData)"
//
//        return [
//            .summary: "\(key.rawRepresentation) \(sealed) \(key)",
//            .decryptedSentinel: decryptedSentinel,
//            .passed: decryptedSentinel == sentinel,
//            .stored: try store(key: key, withName: alias).withStringKeys()]
//    }
    
//    private func store(key:SymmetricKey, withName alias:String) throws -> [KEY: Any] {
//        // First delete any generic key chain item with the same label. If you
//        // don't, the add seems to fail as a duplicate.
//        let deleteQuery:[CFString:Any] = [
//            kSecClass: kSecClassGenericPassword,
//            kSecAttrLabel: alias,
//            
//            // Generic passwords in the keychain use the following two items as
//            // identifying attributes. If you don't set them, a first keychain
//            // item will still be stored, but a second keychain item will be
//            // rejected as a duplicate.
//            // TOTH: https://useyourloaf.com/blog/keychain-duplicate-item-when-adding-password/
//            kSecAttrAccount: "Account \(alias)",
//            kSecAttrService: "Service \(alias)"
//
//        ]
//        let deleted = SecItemDelete(deleteQuery as CFDictionary)
//        guard deleted == errSecSuccess || deleted == errSecItemNotFound else {
//            throw osStatusError("Failed SecItemDelete(\(deleteQuery)).", deleted)
//        }
//
//        // Merge in more query attributes, to create the add query.
//        let addQuery = deleteQuery.merging([
//            kSecReturnAttributes: true,
//            kSecValueData: key.rawRepresentation,
//        ]) {(_, new) in new}
//        var result: CFTypeRef?
//        let status = SecItemAdd(addQuery as CFDictionary, &result)
//        guard status == errSecSuccess else {
//            throw osStatusError("Failed SecItemAdd(\(addQuery),)", status)
//        }
//        return [.summary: summarise(cfDictionary: result as! CFDictionary),
//                .deletedFirst: deleted == errSecSuccess]
//    }
//    
//    private func tag(forAlias alias: String) -> (String, Data) {
//        let tagString = "com.example.keys.\(alias)"
//        return (tagString, tagString.data(using: .utf8)!)
//    }
//
//    private func generateKeyPair(_ alias:String) throws -> Dictionary<KEY, Any>
//    {
//        // Code snippets are here:
//        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys
//        
//        let tagSD = self.tag(forAlias: alias)
//        let attributes: [CFString: Any] = [
//
//            // Next two lines are OK to create an RSA key.
//            kSecAttrKeyType: kSecAttrKeyTypeRSA,
//            kSecAttrKeySizeInBits: 2048,
//
//            // Next two lines are OK to create an elliptic curve key.
//            // kSecAttrKeySizeInBits: 256,
//            // kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
//
//            // If you set an incompatible combination of bit size and type, you
//            // get an OSstatus -50, which indicates that a parameter has an
//            // invalid value.
//
//            kSecPrivateKeyAttrs: [
//                kSecAttrIsPermanent: true,
//                kSecAttrLabel: alias,
//                kSecAttrApplicationTag: tagSD.1
//            ]
//        ]
//        
//        var error: Unmanaged<CFError>?
//        guard let privateKey = SecKeyCreateRandomKey(
//            attributes as CFDictionary, &error) else
//        {
//            throw error!.takeRetainedValue() as Error
//        }
//        
//        // Make a copy of the attributes dictionary except with values that are:
//        // -   Serialisable to JSON.
//        // -   Descriptive instead of numeric.
//        var returning = attributes
//        returning[kSecAttrKeyType] = keyTypeSummary(
//            attributes[kSecAttrKeyType]!).withStringKeys()
//        returning[kSecPrivateKeyAttrs] = (
//            attributes[kSecPrivateKeyAttrs] as! [CFString:Any])
//            .merging([kSecAttrApplicationTag: tagSD.0]) {(_, new) in new}
//            .withStringKeys()
//
//        return [
//            .sentinel: try encrypt(
//                sentinel: "Centennial", basedOnPrivateKey: privateKey
//            ).withStringKeys(),
//            .attributes: returning.withStringKeys(),
//            .key: self.summarise(key:privateKey).withStringKeys()
//        ]
//    }
//    
//    let keyTypes = [
//        kSecAttrKeyTypeRSA : "RSA",
//        kSecAttrKeyTypeECSECPrimeRandom : "EC"
//
//        // kSecAttrKeyTypeEC : "EC (deprecated)"
//        //
//        // kSecAttrKeyTypeEC is deprecated but has the same value as
//        // kSecAttrKeyTypeECSECPrimeRandom. This means that the both of them
//        // can't be keys in the same dictionary, and that there's no way to
//        // tell the difference by matching.
//    ]
    
//    private func keyTypeSummary(_ specifier: Any) -> [KEY: Any] {
//        var typeText:String?
//
//        // The values for the key type attribute, kSecAttrKeyType, have slightly
//        // strange behaviour.
//        //
//        // In the dictionary passed to SecKeyCreateRandomKey, the value of the
//        // kSecAttrKeyType attribute is a CFString. However, the contents of the
//        // CFString will be numeric. For example, kSecAttrKeyTypeRSA has the
//        // value "42". See, for example:
//        // https://opensource.apple.com/source/Security/Security-55471/sec/Security/SecItemConstants.c.auto.html
//        //
//        // In the dictionary returned from SecItemCopyMatching, the value of the
//        // kSecAttrKeyType attribute will be a CFNumber.
//
//        // If the specifier is a number, compare to the numbers in each
//        // kSecAttrKeyType constant.
//        if let typeNumber = specifier as? NSNumber,
//            let typeInt = Int(exactly: typeNumber)
//        {
//            typeText = keyTypes.first(where: {
//                Int($0.key as String) == typeInt
//            })?.value
//        }
//
//        // If the specifier isn't a number, or didn't match, try it as a string
//        // instead.
//        if typeText == nil, let typeString = specifier as? String {
//            typeText = keyTypes[typeString as CFString] ?? typeString
//        }
//        
//        return [.key: typeText as Any, .raw: specifier]
//    }
//    
//    private let algorithms = [
//        SecKeyAlgorithm.eciesEncryptionStandardX963SHA1AESGCM,
//        SecKeyAlgorithm.rsaEncryptionOAEPSHA512
//    ]
//    
//    private func encrypt(
//        sentinel:String, basedOnPrivateKey privateKey:SecKey
//    ) throws -> Dictionary<KEY, Any>
//    {
//        // Official code snippets are here:
//        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/using_keys_for_encryption
//
//        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
//            throw CaptiveWebView.ErrorMessage("No public key.")
//        }
//
//        guard let algorithm = algorithms.first(
//            where: { SecKeyIsAlgorithmSupported(publicKey, .encrypt, $0)}
//            ) else
//        {
//            throw CaptiveWebView.ErrorMessage("No algorithms supported")
//        }
//        
//        var error: Unmanaged<CFError>?
//        guard let encryptedBytes = SecKeyCreateEncryptedData(
//            publicKey, algorithm, Data(sentinel.utf8) as CFData, &error) else {
//            throw error!.takeRetainedValue() as Error
//        }
//        
//        guard let decryptedBytes = SecKeyCreateDecryptedData(
//            privateKey, algorithm, encryptedBytes, &error) else {
//            throw error!.takeRetainedValue() as Error
//        }
//        
//        let decryptedSentinel = String(
//            data: decryptedBytes as Data, encoding: .utf8)
//            ?? "\(decryptedBytes)"
//        
//        return [
//            .sentinel: sentinel,
//            .encryptedSentinel: String(describing: encryptedBytes),
//            .decryptedSentinel: decryptedSentinel,
//            .passed: decryptedSentinel == sentinel,
//            .algorithm: algorithm.rawValue
//        ]
//    }
//
}
