// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import UIKit
import WebKit

import os.log

extension CaptiveWebView.ViewController {
    
    internal static let nameSuffix = "ViewController"
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        self.view = CaptiveWebView.makeWebView(
            frame: self.view.frame, commandHandler: nil)
    }

    public func loadCustom(scheme:String = "local",
                           file:String = "index.html") -> URL
    {
        return CaptiveWebView.load(in: self.view as! WKWebView,
                                   scheme:scheme,
                                   file:file)
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
        CaptiveWebView.sendObject(to: self.view as! WKWebView,
                                  command,
                                  completionHandler)
    }
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
