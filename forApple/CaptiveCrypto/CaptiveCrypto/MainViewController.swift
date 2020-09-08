//
//  ViewController.swift
//  CaptiveCrypto
//
//  Created by Jim Hawkins on 07/09/2020.
//  Copyright © 2020 Jim Hawkins. All rights reserved.
//

import UIKit
import CaptiveWebView

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
    func withStringKeys() -> Dictionary<String, Value> {
        return Dictionary<String, Value>(uniqueKeysWithValues: self.map {
            ($0.rawValue, $1)
        })
    }
}

class MainViewController: CaptiveWebView.DefaultViewController {

    // Implicit raw values, see:
    // https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html#ID535
    private enum Command: String {
        case deleteAll, dump, generatePair
    }
    
    public enum KEY: String {
        case alias, attributes, deletedAll, parameters, keys, count, dump, key
    }
    
    override func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any>
    {
        switch Command(rawValue: command) {
            
        case .deleteAll:
            return try deleteAllKeys()
            
        case .dump:
            return try dumpKeyStore()

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
            return try generateKeyPair(alias)

        default:
            return try super.response(to: command, in: commandDictionary)
        }
    }
    
    private func deleteAllKeys() throws -> Dictionary<String, Any> {
        // Query to find all keys.
        let query: [String: Any] = [kSecClass as String: kSecClassKey]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess else {
            throw osStatusError(status)
        }
        return [KEY.deletedAll: true].withStringKeys()
    }
    
    private func osStatusError(_ osStatus: OSStatus) -> Error {
        // Plan A: use the proper method to create an error message.
        if let message = SecCopyErrorMessageString(osStatus, nil) {
            // The reference for SecCopyErrorMessageString is here:
            // https://developer.apple.com/documentation/security/1394686-seccopyerrormessagestring
            //
            // It says: "Call the CFRelease function to release this object
            // when you are finished using it." Presume like this:
            // CFRelease(message)
            //
            // However, if you do then Xcode flags an error:
            // 'CFRelease' is unavailable: Core Foundation objects are
            // automatically memory managed
            //
            // It also says to pass NULL as the second parameter, which
            // isn't accepted by the compiler. This code passes nil instead.

            return CaptiveWebView.ErrorMessage(message)
        }
        
        // Plan B: create an NSError instead.
        return NSError(domain: NSOSStatusErrorDomain, code: Int(osStatus))
    }
    
    private func dumpKeyStore() throws -> Dictionary<String, Any> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitAll
        ]
        // Above query uses kSecReturnAttributes to get a CFDictionary
        // representation of each key. Setting kSecReturnRef true instead gets a
        // SecKey for each key. A dictionary representation can be generated
        // from a SecKey by calling SecKeyCopyAttributes(), which is done in the
        // dump(key:) method, below. However the resulting dictionary has only a
        // subset of the attributes. For example, it doesn't have these:
        //
        // -   kSecAttrLabel
        // -   kSecAttrApplicationTag
        
        var itemRef: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &itemRef)
        
        // Set items to an NSArray of the return value, or an empty NSArray.
        let items = status == errSecSuccess
            ? (itemRef as! CFArray) as NSArray
            : NSArray()
        
        // If SecItemCopyMatching failed, status will be a numeric error code.
        // To find out what a particular number means, you can look it up on
        // this:
        // https://www.osstatus.com/search/results?platform=all&framework=all&search=errSec
        // That will get you the symbolic name.
        //
        // Symbolic names can be looked up in the official reference:
        // https://developer.apple.com/documentation/security/1542001-security_framework_result_codes
        // But it isn't searchable by number.
        //
        // This is how Jim found out that -25300 is errSecItemNotFound.

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw osStatusError(status)
        }
        
        var store:[Dictionary<String, Any>] = []

        // In case of errSecItemNotFound, items will be an empty array.
        items.enumerateObjects {
            (item: Any, index: Int, stop: UnsafeMutablePointer<ObjCBool>) in
            store.append(self.dump(cfDictionary: item as! CFDictionary))
        }
        
        return [KEY.keys: store, KEY.count: items.count].withStringKeys()
    }
    
    private func dump(key secKey: SecKey) -> Dictionary<String, Any> {
        var dumpAttributes: Dictionary<String, Any>? = nil
        if let copyAttributes = SecKeyCopyAttributes(secKey) {
            dumpAttributes = self.dump(cfDictionary: copyAttributes)
        }
        
        return [
            KEY.dump: "\(secKey)".split(separator: ","),
            KEY.attributes: dumpAttributes ?? "null"
        ].withStringKeys()
    }
    
    private func dump(cfDictionary: CFDictionary) -> Dictionary<String, Any> {
        var returning: Dictionary<String, Any> = [:]
        for (rawKey, rawValue) in cfDictionary as NSDictionary {
            let value = JSONSerialization.isValidJSONObject(rawValue)
                ? rawValue
                : "\(rawValue)"
            
            if let key = rawKey as? String {
                if key == kSecAttrApplicationTag as String {
                    let cfValue = rawValue as! CFData
                    returning[key] = String(
                        data: cfValue as Data, encoding: .utf8)
                }
                else {
                    returning[key] = value
                }
            }
            else {
                returning[String(describing: rawKey)] = value
            }
        }
        return returning
    }

    private func generateKeyPair(_ alias:String) throws
        -> Dictionary<String, Any>
    {
        
        // Code snippets are here:
        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys

        let tag = "com.example.keys.\(alias)"
        let attributes: [String: Any] = [
            
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            // Setting kSecAttrKeyTypeEC instead results in OSstatus -50, which
            // indicates that a parameter has an invalid value.

            kSecAttrKeySizeInBits as String: 2048,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrLabel as String: alias,
                kSecAttrApplicationTag as String: tag.data(using: .utf8)!
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        
        // Next statement includes a copy of the attributes dictionary except
        // with all JSON serialisable values.
        return [
            KEY.attributes: [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA as String,
                 kSecAttrKeySizeInBits as String: 2048,
                 kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrApplicationTag as String: tag
                ]
            ],
            KEY.key: self.dump(key:privateKey)
        ].withStringKeys()
    }

}
