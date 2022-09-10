// Copyright 2022 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

#if os(iOS)
import Foundation
import WebKit

private enum Command: String {
    case close, fetch, focus, load, write, EMPTY = ""
}

private enum KEY: String {
    // Common keys.
    case command, confirm, failed, load, secure, parameters
    
    // Keys used by the `close` command.
    case closed
    
    // Keys used by `fetch` command.
    case resource, options, method, body, bodyObject, headers, fetched,
         fetchError
    
    // Keys used by `load` command.
    case page, loaded, dispatched
    
    // Keys used by `write` command.
    case base64decode, text, filename, wrote
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
        ) throws -> Dictionary<String, Any>
    {
        switch Command(rawValue:command) {
        case .close:
            viewController.dismiss(animated: true, completion: nil)
            return [.closed: true].withStringKeys()
        
        case .fetch:
            return try builtInFetch(commandDictionary)

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

    public static func builtInFetch(
        _ commandDictionary: Dictionary<String, Any>
    ) throws -> Dictionary<String, Any>
    {
        let parameters = commandDictionary[.parameters]
            as? Dictionary<String, Any> ?? [:]
        
        guard let resource = parameters[.resource] as? String else {
            throw CaptiveWebView.ErrorMessage("No resource specified.")
        }
        guard let url = URL(string: resource) else {
            throw CaptiveWebView.ErrorMessage("Resource isn't a URL.")
        }
        
        var request = URLRequest(url: url)
        
        if let options = parameters[.options] as? Dictionary<String, Any> {
            if let method = options[.method] as? String {
                request.httpMethod = method
            }
            if let body = options[.body] as? String {
                request.httpBody = body.data(using: .utf8)
                request.addValue(
                    "application/json", forHTTPHeaderField: "Content-Type")
            }
            if let bodyObject = options[.bodyObject]
                as? Dictionary<String, Any>
            {
                request.addValue(
                    "application/json", forHTTPHeaderField: "Content-Type")
                var httpBody = try JSONSerialization.data(
                    withJSONObject: bodyObject)
                httpBody.append(contentsOf: "\r\n\r\n".utf8)
                request.httpBody = httpBody
                // let body = String(data: request.httpBody!, encoding: .utf8)
                request.addValue(
                    "application/json", forHTTPHeaderField: "Content-Type")
            }
            if let headers = options[.headers] as? Dictionary<String, String>
            {
                for header in headers {
                    request.addValue(
                        header.value, forHTTPHeaderField: header.key)
                }
            }
        }
        
        var fetchedData:Data? = nil
        var fetchError:Error? = nil
        // TOTH synchronous HTTP request.
        // https://stackoverflow.com/a/64476948/7657675
        let group = DispatchGroup()
        group.enter()
        let task = URLSession.shared.dataTask(with: request) {
            (data, response, error) in
            defer {group.leave()}
            fetchError = error
            fetchedData = data
        }
        task.resume()
        group.wait()

        var return_:Dictionary<String, Any> = [:]
        if let fetchedData = fetchedData {
            return_[.fetched] = try JSONSerialization.jsonObject(
                with: fetchedData,
                options: JSONSerialization.ReadingOptions.allowFragments)
        }
        if let fetchError = fetchError {
            return_[.fetchError] = fetchError.localizedDescription as Any
        }
        return return_
    }
    
    static func builtInLoad(
        _ viewController: CaptiveWebView.DefaultViewController,
        _ commandDictionary: Dictionary<String, Any>
    ) throws -> Dictionary<String, Any>
    {
        let parameters = commandDictionary[.parameters]
            as? Dictionary<String, Any> ?? [:]
        
        guard let page = parameters[.page] as? String else {
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
        // loaded and so is a blank rectangle of the system background
        // colour. The contents of the current view disappear but there's no
        // sense of them being covered from bottom to top. The following
        // code addresses this by adding a thin border, and removing the
        // border after presentation.
        // The flipHorizontal transition doesn't seem to have this problme,
        // but it's old-fashioned looking.
        loadedController.view.layer.borderWidth = 1.0
        loadedController.view.layer.borderColor = UIColor.label.cgColor
        viewController.present(loadedController, animated: true) {
            loadedController.view.layer.borderWidth = 0
        }
        return [.loaded: page].withStringKeys()
    }
    
    public static func builtInWrite(
        _ commandDictionary: Dictionary<String, Any>
    ) throws -> Dictionary<String, Any>
    {
        let parameters = commandDictionary[.parameters]
            as? Dictionary<String, Any> ?? [:]
        
        // Get the parameters.
        guard let text = parameters[.text] as? String else {
            throw CaptiveWebView.ErrorMessage(
                "No text in parameters for write command: \(parameters)")
        }
        guard let filename = parameters[.filename] as? String else {
            throw CaptiveWebView.ErrorMessage(
                "No filename in parameters for write command: \(parameters)")
        }
        let asciiToBinary = parameters[.base64decode] as? Bool ?? false

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
        if asciiToBinary {
            let data = Data(base64Encoded: text)
            try data?.write(to: fileURL)
        }
        else {
            try text.write(to:fileURL, atomically: true, encoding: .utf8)
        }

        // Generate a relative path that should be meaningful to the user.
        let root = URL.init(fileURLWithPath: NSHomeDirectory())
            .absoluteString
        let absolutePath = fileURL.absoluteString
        let relativePath = absolutePath.hasPrefix(root)
            ? String(fileURL.absoluteString.suffix(
                        absolutePath.count - root.count))
            : absolutePath
            
        return [.wrote: relativePath].withStringKeys()
    }
}


#endif
