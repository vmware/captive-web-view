// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Cocoa
import WebKit

import MacCaptiveWebView

class ViewController: NSViewController, CaptiveWebViewCommandHandler {
    func handleCommand(
        _ command: Dictionary<String, Any>) -> Dictionary<String, Any>
    {
        // Dummy handler for now.
        return command
    }
    
    var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()

        self.webView = MacCaptiveWebView.CaptiveWebView.makeWebView(
            frame: self.view.frame, commandHandler: self)
        self.view.addSubview(self.webView, positioned: .below, relativeTo: nil)
        MacCaptiveWebView.CaptiveWebView.constrain(view:webView, to:view)

        // Uncomment the following to add a diagnostic border around the web
        // view.
        // self.webView.layer?.borderColor = NSColor.blue.cgColor
        // self.webView.layer?.borderWidth = 4.0
        // self.webView.layer?.backgroundColor = NSColor.yellow.cgColor

        _ = MacCaptiveWebView.CaptiveWebView.load(
            in: self.webView, scheme: "local", file: "Main.html")
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}
