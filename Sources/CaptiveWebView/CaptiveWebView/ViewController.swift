// Copyright 2020 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

#if os(iOS)
import Foundation
import UIKit
import WebKit

import os.log

extension CaptiveWebView.ViewController {
    
    internal static let nameSuffix = "ViewController"

    override open func loadView() {
        // Root view is a generic UIView. The OS will resize it to the size of
        // the screen.
        // Note that the web view isn't used as the root view. The web view can
        // then easily be constrained to the safe area. The root view fills the
        // whole screen; the web view will fill the safe area.
        view = UIView()

        setColours()

        // The web view will have been instantiated by the property initialiser.
        // It doesn't get inserted into the view hierarchy until now though.
        // Hide it before inserting it.
        webView.isHidden = true
        view.addSubview(webView)

        // Uncomment the following to add a diagnostic border around the web
        // view.
        // self.webView.layer.borderColor = UIColor.blue.cgColor
        // self.webView.layer.borderWidth = 4.0
        // self.webView.layer.backgroundColor = UIColor.yellow.cgColor
        // self.view.layer.backgroundColor = UIColor.cyan.cgColor

        // Load the web resources. This also causes invocation of the
        // WKNavigationDelegate didCommit callback, which is in the
        // CaptiveWebView.swift file.
        _ = self.loadMainHTML()

        // The web view will have been instantiated with a zero frame. Now that
        // it's in the view hierarchy, it can be constrained to the safe area.
        // Note that the constraint can't be applied before the web view is
        // inside the view hierarchy, and only constraints to other views in the
        // same hierarchy are allowed.
        CaptiveWebView.constrain(view: webView, to: view.safeAreaLayoutGuide)
    }
    
    // It seems that the first time a WKWebView is loaded, it will appear
    // as a white rectangle. The appearance can be very brief, like a white
    // flash. That's a problem in dark mode because the appearance before
    // and after will be of a black screen. The fix is to hide the web view
    // for half a second.
    // The hiding takes place in the loadView, above, for example. The showing
    // is scheduled from here, in the navigation didCommit callback. That's
    // actually the only reason this ViewController subclass is also a
    // WKNavigationDelegate.
    public func webView(
        _ webView: WKWebView, didCommit navigation: WKNavigation!
    ) {
        webView.isHidden = true
        if let interval = loadVisibilityTimeOutSeconds {
            Timer.scheduledTimer(withTimeInterval: interval, repeats: false) {
                (timer:Timer) in webView.isHidden = false
            }
        }
        else {
            webView.isHidden = false
        }
    }
    
    private func setColours() {
        view.layer.backgroundColor = UIColor.systemBackground.cgColor
        webView.layer.backgroundColor = UIColor.systemBackground.cgColor
    }

    open override func traitCollectionDidChange(
        _ previousTraitCollection: UITraitCollection?
    ) {
        // This callback is invoked when the device is changed between dark mode
        // and light mode. Resetting the colours to systemBackground will apply
        // the new mode.
        if previousTraitCollection?.userInterfaceStyle
            != traitCollection.userInterfaceStyle
        {
            setColours()
        }
    }

    public func loadCustom(scheme:String = CaptiveWebView.scheme,
                           file:String = "index.html") -> URL
    {
        return CaptiveWebView.load(in: webView, scheme:scheme, file:file)
    }
    
    public func loadMainHTML() -> URL {
        // Next line has a reference to the mainHTML property, which is declared
        // in the CaptiveWebView.swift file, in the class placeholder. It can't
        // be declared here in the extension.
        return self.loadCustom(file: mainHTML)
    }
    
    static func mainHTML(from viewController:UIViewController) -> String {
        var subClass = String(describing:type(of: viewController))
        if subClass.hasSuffix(CaptiveWebView.ViewController.nameSuffix) {
            subClass.removeLast(
                CaptiveWebView.ViewController.nameSuffix.count)
        }
        subClass.append(".html")
        return subClass
    }
    
    public func sendObject(
        _ command:Dictionary<String, Any>,
        _ completionHandler:((Any?, Error?) -> Void)? = nil)
    {
        CaptiveWebView.sendObject(to: webView, command, completionHandler)
    }
}
#endif
