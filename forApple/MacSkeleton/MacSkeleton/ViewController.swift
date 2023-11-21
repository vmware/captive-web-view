// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Cocoa
import WebKit

import CaptiveWebView

class MainViewController: CaptiveWebView.ViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bridge = self
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}
