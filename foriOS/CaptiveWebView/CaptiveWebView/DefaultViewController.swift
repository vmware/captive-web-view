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

private let FOCUS_COMMAND = "focus"
private let LOAD_COMMAND = LOAD_PAGE_KEY
private let CLOSE_COMMAND = "close"

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
                throw ErrorMessage.message(
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
        catch ErrorMessage.message(let message) {
            returning[EXCEPTION_KEY] = message
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
        
        switch command {
        case CLOSE_COMMAND:
            viewController.dismiss(animated: true, completion: nil)
            return ["closed": true]

        case FOCUS_COMMAND:
            return ["focussed controller": viewController.becomeFirstResponder()]
            
        case LOAD_COMMAND:
            guard let page = parameters["page"] as? String else {
                throw ErrorMessage.message("No page specified.")
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
                throw ErrorMessage.message(
                    "Page \"\(page)\" isn't in viewControllerMap")
            }
            let loadedController = controllerClass.init()
            // TOTH: https://zonneveld.dev/ios-13-viewcontroller-presentation-style-modalpresentationstyle/
            loadedController.modalPresentationStyle = .fullScreen
            loadedController.modalTransitionStyle = .flipHorizontal
            viewController.present(loadedController, animated: true)
            return ["loaded": page]
            
        case "":
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
            throw ErrorMessage.message("Unknown command \"\(command)\"")
        }
    }
}

// An enum subclass seems to be the simplest way to create a throw-able that has
// a message that can be retrieved in the catch. Jim couldn't manage to create
// an Error subclass that overrides localizedDescription. Also couldn't seem to
// catch with a pattern and then access the thrown object in the catch block.
private enum ErrorMessage: Error {
    case message(_ message:String)
}
#endif
