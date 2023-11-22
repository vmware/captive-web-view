// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Cocoa
import WebKit

import CaptiveWebView

class MainViewController: CaptiveWebView.DefaultViewController {

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }

}
