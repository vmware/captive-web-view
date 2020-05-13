// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause
#if os(iOS)
import Foundation
import UIKit
import WebKit

import os.log

extension CaptiveWebView.ViewController {
    
    internal static let nameSuffix = "ViewController"
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.webView = CaptiveWebView.makeWebView(
            frame: self.view.frame, commandHandler: nil)
        self.view.insertSubview(self.webView, at:0)
        CaptiveWebView.constrain(view: webView, to: view.safeAreaLayoutGuide)
        self.view.layer.backgroundColor = UIColor.white.cgColor

        // Uncomment the following to add a diagnostic border around the web
        // view.
        // self.webView.layer.borderColor = UIColor.blue.cgColor
        // self.webView.layer.borderWidth = 4.0
        // self.webView.layer.backgroundColor = UIColor.yellow.cgColor
        // self.view.layer.backgroundColor = UIColor.cyan.cgColor
    }

    public func loadCustom(scheme:String = "local",
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
