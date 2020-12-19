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
//        super.loadView()
        view = UIView()

        view.layer.backgroundColor = UIColor.systemBackground.cgColor

//        self.coverView.layer.backgroundColor = UIColor.systemBackground.cgColor
//        self.coverView.layer.opacity = 0.7
//        self.view.addSubview(self.coverView)
//        CaptiveWebView.constrain(view: self.coverView, to: self.view)

        webView = CaptiveWebView.makeWebView(
            frame: self.view.frame, commandHandler: nil)
        //webView.navigationDelegate = self
 
        webView.layer.backgroundColor = UIColor.systemBackground.cgColor
        webView.isHidden = true
        view.addSubview(webView)


        //if webView.url == nil {
            _ = self.loadMainHTML()
        //}

//        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
//            if webView.isHidden {
        Timer.scheduledTimer(
            withTimeInterval: firstLoadVisibilityTimeOutSeconds,
            repeats: false
        ) {
            (timer:Timer) in self.webView.isHidden = false
        }
        
        CaptiveWebView.constrain(view: webView, to: view.safeAreaLayoutGuide)
    }
    
//    override open func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//    }
    
    override open func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
//        self.webView.isHidden = false
//        self.webView.layer.opacity = 1
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
//        self.webView = CaptiveWebView.makeWebView(
//            frame: self.view.frame, commandHandler: nil)
//        self.webView.layer.backgroundColor = UIColor.systemBackground.cgColor
//        var red = CGFloat(1), green = CGFloat(1), blue = CGFloat(1), alpha = CGFloat(1)
//        let got = UIColor.systemBackground.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
//        let cssColour = "rgba(\(red * 100)%, \(green * 100)%, \(blue * 100)%, \(alpha * 100)%)"
        
//        self.webView.loadHTMLString("<body style=\"background-color:\(cssColour);\">Hi</body>", baseURL: nil)
//        self.webView.isHidden = true
//        self.webView.layer.opacity = 0
        //self.view.addSubview(self.webView)
//        self.view.insertSubview(webView, belowSubview: coverView)
//        webView.layer.opacity = 0.1
//        CaptiveWebView.constrain(view: webView, to: view.safeAreaLayoutGuide)

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
