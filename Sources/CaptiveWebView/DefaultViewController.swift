// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import WebKit

private enum Command: String {
    case close, fetch, focus, load, write, EMPTY = ""
}

private enum KEY: String {
    // Common keys.
    case command, confirm, failed, load, secure, parameters, dispatched
    
    // Keys used by the `close` command.
    case closed   
}

// Convenience extension to facilitate use of the KEY enumeration as keys in a
// dictionary. TOTH for the setter:
// https://www.avanderlee.com/swift/custom-subscripts/#making-a-read-and-write-subscript
extension Dictionary where Key == String {
    fileprivate subscript(_ key:KEY) -> Value? {
        get {
            self[key.rawValue]
        }
        set {
            self[key.rawValue] = newValue
        }
    }
}

// Clunky but can be used to create a dictionary with String keys from a
// dictionary literal with KEY keys.
extension Dictionary where Key == KEY {
    func withStringKeys() -> [String: Value] {
        return Dictionary<String, Value>(uniqueKeysWithValues: self.map {
            ($0.rawValue, $1)
        })
    }
}

#if os(iOS)

extension CaptiveWebView.DefaultViewController {

    override open func loadView() {
        bridge = self
        super.loadView()
    }

    static func handleCommand(
        _ viewController: CaptiveWebView.DefaultViewController,
        _ command: Dictionary<String, Any>
        ) -> Dictionary<String, Any>
    {
        var returning = command
        do {
            let commandAny:Any = command[.command] ?? ""
            guard let commandString = commandAny as? String else {
                throw CaptiveWebView.ErrorMessage(
                    "Command isn't String: " + String(describing: commandAny))
            }

            let responded = try viewController.response(to:commandString,
                                                        in:command)
            returning.merge(responded) {(_, new) in new}
            // Confirmation message starts with the class name of self.
            // TOTH: https://stackoverflow.com/a/34878224
            returning[.confirm] =
                String(describing: type(of: viewController)) + " bridge OK."
            returning[.secure] = viewController.webView.hasOnlySecureContent
        }
        catch let error as CaptiveWebView.ErrorMessage {
            returning[.failed] = error.localizedDescription
        }
        catch {
            returning[.failed] = error.localizedDescription
        }
        return returning

    }
    
    static func response(
        _ viewController: CaptiveWebView.DefaultViewController,
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any?>
    {
        switch Command(rawValue:command) {
        case .close:
            viewController.dismiss(animated: true, completion: nil)
            return [.closed: true].withStringKeys()
        
        case .fetch:
            return try builtInFetch(commandDictionary) {nsError in
                // Placeholder for logging or taking some other action with the
                // cause of an exception. The exception itself will have been
                // rendered into JSON and returned to the JS layer.
                let thrown = nsError
            } as Dictionary<String, Any?>

        case .focus:
            return ["focussed controller": viewController.becomeFirstResponder()]
            
        case .load:
            return try builtInLoad(viewController, commandDictionary)
            
        case .write:
            return try builtInWrite(commandDictionary)
            
        case .EMPTY:
            if let page = commandDictionary[.load] as? String {
                // This branch handles a command like this:
                //
                //     {"load": "pagetoload.html"}
                //
                // It loads a new page in the same view controller. That is
                // different to this:
                //
                //     {"command": "load", "parameters": {"page": "spec"}}
                //
                // That loads a new view controller.
                
                // The dispatch mightn't be necessary but it seems better than
                // loading the web view here, when it's in the middle of
                // receiving a response.
                DispatchQueue.main.async {
                    _ = viewController.loadCustom(file:page)
                }
                //
                // The dispatched load will bin the web content, including the
                // JS that receives the confirmation. If it logs it, that log
                // will be cleared before it can be seen, if everything is OK.
                return [.dispatched: page].withStringKeys()
            }
            else {
                // Empty dictionary.
                return [:]
            }

        default:
            throw CaptiveWebView.ErrorMessage("Unknown command \"\(command)\"")
        }
    }


}


#endif
