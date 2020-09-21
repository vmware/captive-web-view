// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

#if os(iOS)
import Foundation
import WebKit

private let CONFIRM_KEY = "confirm"
private let COMMAND_KEY = "command"
private let EXCEPTION_KEY = "failed"
private let LOAD_PAGE_KEY = "load"
private let SECURE_KEY = "secure"

private enum Command: String {
    case close, focus, load, write, EMPTY = ""
}

private enum KEY: String {
    // Keys used by `write` command.
    case text, filename, wrote
    
    // ToDo replace all the _KEY constants, above, with enumerated values.
}

// Convenience extension to facilitate use of the KEY enumeration as keys in a
// dictionary.
extension Dictionary where Key == String {
    fileprivate subscript(_ key:KEY) -> Value? {
        get {
            return self[key.rawValue]
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

extension CaptiveWebView.DefaultViewController {

    override open func viewDidLoad() {
        super.viewDidLoad()
        self.bridge = self
        // Don't load here; load in the viewDidAppear instead.
    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if webView.url == nil {
            _ = self.loadMainHTML()
        }
        else {
            // This code runs if another ViewController was show()'n from this
            // one and it then dismiss()'d. The PasscodeStream needs this,
            // because it has to reload the configuration and passcode in the
            // diagnostic Index screen.
            // Commented out in the general case for now.
            // webView.reload()
        }
    }
    
    static func handleCommand(
        _ viewController: CaptiveWebView.DefaultViewController,
        _ command: Dictionary<String, Any>
        ) -> Dictionary<String, Any>
    {
        var returning = command
        do {
            let commandAny:Any = command[COMMAND_KEY] ?? ""
            guard let commandString = commandAny as? String else {
                throw CaptiveWebView.ErrorMessage(
                    "Command isn't String: " + String(describing: commandAny))
            }

            let responded = try viewController.response(to:commandString,
                                                        in:command)
            returning.merge(responded) {(_, new) in new}
            // Confirmation message starts with the class name of self.
            // TOTH: https://stackoverflow.com/a/34878224
            returning[CONFIRM_KEY] =
                String(describing: type(of: viewController)) + " bridge OK."
            returning[SECURE_KEY] = viewController.webView.hasOnlySecureContent
        }
        catch let error as CaptiveWebView.ErrorMessage {
            returning[EXCEPTION_KEY] = error.localizedDescription
        }
        catch {
            returning[EXCEPTION_KEY] = error.localizedDescription
        }
        return returning

    }
    
    static func response(
        _ viewController: CaptiveWebView.DefaultViewController,
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any>
    {
        let parameters = commandDictionary["parameters"]
            as? Dictionary<String, Any> ?? [:]
        
        switch Command(rawValue:command) {
        case .close:
            viewController.dismiss(animated: true, completion: nil)
            return ["closed": true]

        case .focus:
            return ["focussed controller": viewController.becomeFirstResponder()]
            
        case .load:
            guard let page = parameters["page"] as? String else {
                throw CaptiveWebView.ErrorMessage("No page specified.")
            }
            
            // The Captive Web View for Android has a map of page to Activity
            // subclass. That's because Kotlin introspection would require an
            // extra library in the application. The iOS runtime provides a form
            // of introspection built-in, so there's no need for a map here ...
            // except there is. The following looks promising but doesn't work.
            //
            // guard let controllerClass =
            //     Bundle.main.classNamed(page + "ViewController")
            //         as? UIViewController.Type
            //     else {
            //         throw ErrorMessage.message("No ViewController for \"\(page)\".")
            // }
            
            guard let controllerClass = viewControllerMap[page] else {
                throw CaptiveWebView.ErrorMessage(
                    "Page \"\(page)\" isn't in viewControllerMap")
            }
            let loadedController = controllerClass.init()
            // TOTH: https://zonneveld.dev/ios-13-viewcontroller-presentation-style-modalpresentationstyle/
            loadedController.modalPresentationStyle = .fullScreen

            loadedController.modalTransitionStyle = .coverVertical
            // During the vertical cover animation, the web view hasn't been
            // loaded and so is a blank white rectangle. The sense of the
            // current view being covered is therefore lost. The following code
            // addresses this by adding a thin black border, and removing the
            // border after presentation.  
            // The flipHorizontal transition doesn't seem to have this problme,
            // but it's old-fashioned looking.
            loadedController.view.layer.borderWidth = 1.0
            loadedController.view.layer.borderColor = UIColor.black.cgColor
            viewController.present(loadedController, animated: true) {
                loadedController.view.layer.borderWidth = 0
            }
            return ["loaded": page]
            
        case .write:
            // Get the parameters.
            guard let text = parameters[KEY.text] as? String else {
                throw CaptiveWebView.ErrorMessage(
                    "No text in parameters for write command: \(parameters)")
            }
            guard let filename = parameters[KEY.filename] as? String else {
                throw CaptiveWebView.ErrorMessage(
                    "No filename in parameters for write command: \(parameters)")
            }

            // Get the Documents/ directory for the app, and append the
            // specified file name.
            // If the app declares UISupportsDocumentBrowser:YES in its
            // Info.plist file then the files written here will be accessible
            // to, for example, the Files app on the device.
            let fileURL = try FileManager.default.url(
                for: .documentDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true)
                .appendingPathComponent(filename)

            // Write the file.
            try text.write(to:fileURL, atomically: true, encoding: .utf8)

            // Generate a relative path that should be meaningful to the user.
            let root = URL.init(fileURLWithPath: NSHomeDirectory())
                .absoluteString
            let absolutePath = fileURL.absoluteString
            let relativePath = absolutePath.hasPrefix(root)
                ? String(fileURL.absoluteString.suffix(
                            absolutePath.count - root.count))
                : absolutePath
                
            return [KEY.wrote: relativePath].withStringKeys()
            
        case .EMPTY:
            if let page = commandDictionary[LOAD_PAGE_KEY] as? String {
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
                return ["dispatched": page]
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
