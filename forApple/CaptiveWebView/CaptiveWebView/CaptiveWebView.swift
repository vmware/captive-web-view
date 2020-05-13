// Copyguide 2020 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import WebKit

// This struct is really a namespace. TOTH:
// https://stackoverflow.com/questions/24002821/how-to-use-namespaces-in-swift#24293236
//
// Actual class code is in extensions in the other .swift files, where possible.
// Some examples of where it isn't possible are:
// 
// -   Property declarations, which aren't allowed in extensions.
// -   Open methods.
// -   Protocol declarations.

public struct CaptiveWebView {

    public class WebResource {}

#if os(macOS)
    
    // macOS version, takes two NSView parameters.
    public static func constrain(
        view left: NSView, to right: NSView, leftSide:Bool = false
    ) {
        left.translatesAutoresizingMaskIntoConstraints = false
        left.topAnchor.constraint(
            equalTo: right.topAnchor).isActive = true
        left.bottomAnchor.constraint(
            equalTo: right.bottomAnchor).isActive = true
        left.leftAnchor.constraint(
            equalTo: right.leftAnchor).isActive = true
        left.rightAnchor.constraint(
            equalTo: leftSide ? right.centerXAnchor : right.rightAnchor
        ).isActive = true
    }
    // TOTH:
    //    https://github.com/dasher-project/redash/blob/master/Keyboard/foriOS/DasherApp/Keyboard/KeyboardViewController.swift#L129

#else
    
    // iOS version, takes either of the following:
    //
    // -   Two UIView parameters.
    // -   One UIView and one UILayoutGuide.
    //
    // The UIView.safeAreaLayoutGuide property is a UILayoutGuide.
    public static func constrain(
        view left: UIView, to right: UIView, leftHalf:Bool = false
    ) {
        setAnchors(of: left,
                   top: right.topAnchor,
                   left: right.leftAnchor,
                   bottom: right.bottomAnchor,
                   right: leftHalf ? right.centerXAnchor : right.rightAnchor)
    }
    
    public static func constrain(
        view: UIView, to guide: UILayoutGuide, leftHalf:Bool = false
    ) {
        setAnchors(of: view,
                   top: guide.topAnchor,
                   left: guide.leftAnchor,
                   bottom: guide.bottomAnchor,
                   right: leftHalf ? guide.centerXAnchor : guide.rightAnchor)
    }

    public static func setAnchors(
        of view: UIView,
        top: NSLayoutYAxisAnchor,
        left:NSLayoutXAxisAnchor,
        bottom: NSLayoutYAxisAnchor,
        right: NSLayoutXAxisAnchor
    ) {
        view.translatesAutoresizingMaskIntoConstraints = false
        view.topAnchor.constraint(equalTo: top).isActive = true
        view.leftAnchor.constraint(equalTo: left).isActive = true
        view.bottomAnchor.constraint(equalTo: bottom).isActive = true
        view.rightAnchor.constraint(equalTo: right).isActive = true
    }
    //   TOTH:
    //    https://github.com/dasher-project/redash/blob/master/Keyboard/foriOS/DasherApp/Keyboard/KeyboardViewController.swift#L129

    
    // The next classes don't have an equivalent in the macOS library. They
    // facilitate programmatic creation of the user interface, which would be a
    // much bigger job on macOS.
    
    open class ViewController: UIViewController {

        var webView: WKWebView!
        
        open var mainHTML:String {return ViewController.mainHTML(from: self)}

        public var bridge:CaptiveWebViewCommandHandler? {
            get {
                (webView.configuration.urlSchemeHandler(forURLScheme: "local")
                    as! CaptiveURLHandler).bridge
            }
            set {
                (webView.configuration.urlSchemeHandler(forURLScheme: "local")
                    as! CaptiveURLHandler).bridge = newValue
            }
        }
        
    }
    
    open class DefaultViewController:
    CaptiveWebView.ViewController, CaptiveWebViewCommandHandler {
        public static var viewControllerMap =
            Dictionary<String, UIViewController.Type>()
        
        // Open methods have to be here, not in the extension, so that they can
        // be overriden.
        // These base class methods call the static methods, which are in the
        // extension, in the DefaultViewController.swift file.
        
        open func handleCommand(_ command: Dictionary<String, Any>) ->
            Dictionary<String, Any>
        {
            return CaptiveWebView.DefaultViewController.handleCommand(
                self, command)
        }

        // This method should be private to this class and any subclass.
        // Swift doesn't seem to have a syntax for that, so its public instead.
        // If it's declared private, it cannot be called from a subclass with
        // super. notation.
        open func response(
            to command: String,
            in commandDictionary: Dictionary<String, Any>
            ) throws -> Dictionary<String, Any>
        {
            return try CaptiveWebView.DefaultViewController.response(
                self, to:command, in:commandDictionary)
        }
    }
    
    open class ApplicationDelegate: UIResponder, UIApplicationDelegate {
        // Following declaration has to be here in the class.
        public var window: UIWindow?
    }
#endif

    public static func makeWebView(frame:CGRect,
                            commandHandler:CaptiveWebViewCommandHandler?
        ) -> WKWebView
    {
        
        /*
         To add other URL schemes, register handlers here with code like the
         following:
         
         webView.configuration.setURLSchemeHandler(self, forURLScheme: "mailto")
         webView.configuration.setURLSchemeHandler(self, forURLScheme: "hucaj")
         
         Registration has to be here and not in the subclass because changes to
         the WKWebViewConfiguration made after the WKWebView has been
         instantiated are ignored.
         */
        return WKWebView(
            frame: frame,
            configuration: CaptiveWebView.makeWebViewConfiguration(
                commandHandler: commandHandler)
        )
    }
    
    public static func makeWebViewConfiguration(
        commandHandler:CaptiveWebViewCommandHandler?
    ) -> WKWebViewConfiguration
    {
        let handler = CaptiveURLHandler()
        
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(handler, forURLScheme: "local")
        configuration.userContentController.add(handler, name: "messageBridge")
        handler.bridge = commandHandler
        return configuration
    }
    
    public static func load(in webView:WKWebView,
                       scheme:String = "local",
                       file:String = "index.html") -> URL
    {
        var builder = URLComponents()
        builder.scheme = scheme

        // We have to get a slash from somewhere. Could just put in a "/" but
        // that seems unsafe. Instead, rely on the first component of the path
        // always being slash.

        if
            let fileURL = CaptiveWebView.WebResource.findFile(
                under: Bundle.main.resourceURL ?? Bundle.main.bundleURL,
                tailComponents: [file]),
            let leadingSlash = fileURL.pathComponents.first
        {
            builder.path = leadingSlash + fileURL.relativePath
        }
        else {
            // This can be expected to fail later, in an orderly fashion, and
            // gets us out of having to throw here.
            builder.path = file
        }

        webView.load(URLRequest(url:builder.url!))
        return builder.url!
    }

    public static func sendObject(
        to webView:WKWebView,
        _ command:Dictionary<String, Any>,
        _ completionHandler:((Any?, Error?) -> Void)? = nil)
    {
        do {
            let jsonData:Data = try JSONSerialization.data(
                withJSONObject:command)
            // The UTF-8 encoding can fail and return nil. Throwing errors is
            // too hard to code in Swift so a JavaScript syntax error with a
            // telltale is introduced instead.
            let jsonString:String =
                String(data:jsonData, encoding:String.Encoding.utf8)
                    ?? "Couldn't encode \(#file) \(#line)"
            webView.evaluateJavaScript(
                "commandBridge.receiveObject(\(jsonString))",
                completionHandler: completionHandler
            )
        }
        catch {
            completionHandler?(nil, error)
        }
    }

}

// Protocol declarations cannot be nested though.
public protocol CaptiveWebViewCommandHandler {
    func handleCommand(_ command:Dictionary<String, Any>)
        -> Dictionary<String, Any>
}

class URLSchemeTaskError: Error {
    let message:String
    
    init(_ message:String) {
        self.message = message
    }
    
    var localizedDescription: String {
        return self.message
    }
    
    var description: String {
        return self.message
    }
}
