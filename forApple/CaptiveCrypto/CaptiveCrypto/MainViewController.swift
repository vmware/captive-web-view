//
//  ViewController.swift
//  CaptiveCrypto
//
//  Created by Jim Hawkins on 07/09/2020.
//  Copyright © 2020 Jim Hawkins. All rights reserved.
//

import UIKit
import CaptiveWebView

class MainViewController: CaptiveWebView.DefaultViewController {

    // Implicit raw values, see:
    // https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html#ID535
    private enum Command: String {
        case generatePair
    }
    
    private enum KEY: String {
        case alias, attributes
    }

    override func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any>
    {
        switch Command(rawValue: command) {
        case .generatePair:
            guard
                let parameters = commandDictionary["parameters"]
                    as? Dictionary<String, Any>,
                let alias = parameters[KEY.alias.rawValue] as? String
            else {
                throw ErrorMessage.message([
                    "Missing `", KEY.alias.rawValue,
                    "` parameter in \(commandDictionary)."]
                    .joined(separator: ""))

            }
            return try generateKeyPair(alias)
        default:
            return try super.response(to: command, in: commandDictionary)
        }
    }


    private func generateKeyPair(_ alias:String) throws
        -> Dictionary<String, Any>
    {
        
        // Reference is here:
        // https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/generating_new_cryptographic_keys

        let tag = "com.example.keys.\(alias)"
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
             kSecAttrKeySizeInBits as String: 2048,
             kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tag.data(using: .utf8)!
            ]
        ]
        
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }
        return [
            KEY.attributes.rawValue: [
                kSecAttrKeyType as String: kSecAttrKeyTypeRSA as String,
                 kSecAttrKeySizeInBits as String: 2048,
                 kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String:    true,
                    kSecAttrApplicationTag as String: tag
                ]
            ],
            "key": "\(privateKey)"
        ]
    }

}


// See note in DefaultViewController.swift file, in the Captive Web View project
// for a discussion of why this is here.
private enum ErrorMessage: Error {
    case message(_ message:String)
}
