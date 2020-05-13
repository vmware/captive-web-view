// Copyright 2019 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import CaptiveWebView

class MainViewController: CaptiveWebView.DefaultViewController {

    override func response(
        to command: String,
        in commandDictionary: Dictionary<String, Any>
        ) throws -> Dictionary<String, Any>
    {
        switch command {
        case "ready":
            return [:]
        default:
            return try super.response(to: command, in: commandDictionary)
        }
    }

}

