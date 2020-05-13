// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import UIKit
import WebKit
import os.log

import CaptiveWebView

class ViewController: UIViewController, CaptiveWebViewCommandHandler {
    var token:String? = nil
    
    func handleCommand(_ command: Dictionary<String, Any>) -> Dictionary<String, Any> {
        guard let tokenAny:Any = command["token"] else {
            os_log("handleCommand(%@)", command)
            resultsLabel.text = String(describing: command)
            return command
        }
        guard let tokenString = tokenAny as? String else {
            var returning = command
            returning["failed"] =
                "Token isn't String: \(String(describing: tokenAny))"
            return returning
        }
        self.token = tokenString
        return command
    }
    
    var wkWebView: WKWebView?
    var numericParameter = 1

    override func viewDidLoad() {
        super.viewDidLoad()

        // Next code instantiates a Captive WKWebView then hides it, then adds
        // it to the view hierarchy. If it isn't added to the hierarchy, the JS
        // running inside it doesn't work well. For example, any code in a
        // setTimeout doesn't execute ever. Also, Fetch promises don't resolve.
        let madeWebView = CaptiveWebView.makeWebView(
            frame:CGRect(x: 0, y: 0, width: 100, height: 100),
            commandHandler: self)
        madeWebView.isHidden = true
        self.view.addSubview(madeWebView as UIView)
        self.wkWebView = madeWebView

        _ = CaptiveWebView.load(in: wkWebView!,
                                scheme: "local",
                                file: "Headless.html")
    }
    
    func sendObjectCallback(result:Any?, error:Error?) {
        os_log(
            "result: %@, error: %@",
            String(describing: result), String(describing: error))
    }

    @IBAction func swapiClicked(_ sender: Any) {
        resultsLabel.text = "Sending\nSWAPI"
        CaptiveWebView.sendObject(
            to: self.wkWebView!, [
                "api":"star-wars",
                "path":["planets", String(describing: numericParameter)]
            ], self.sendObjectCallback)
        numericParameter += 1
    }
    
    @IBAction func goRest401Clicked(_ sender: Any) {
        resultsLabel.text = "Sending\ngo-rest 401"
        CaptiveWebView.sendObject(
            to: self.wkWebView!, [
                "api":"go-rest",
                "path":["users", String(describing: numericParameter + 18)]
            ], self.sendObjectCallback)
    }
    
    @IBAction func goRestQueryParameterClicked(_ sender: Any) {
        resultsLabel.text = "Sending\ngo-rest query parameter"
        CaptiveWebView.sendObject(
            to: self.wkWebView!, [
                "api":"go-rest",
                "path":["users", String(describing: numericParameter + 18)],
                "query-parameter":"access-token",
                "token": self.token ?? "No token"
            ], self.sendObjectCallback)
        numericParameter += 1
    }

    @IBAction func goRestBasicClicked(_ sender: Any) {
        resultsLabel.text = "Sending\ngo-rest basic"
        CaptiveWebView.sendObject(
            to: self.wkWebView!, [
                "api":"go-rest",
                "path":["users", String(describing: numericParameter + 18)],
                "basic-auth":"Bearer",
                "token": self.token ?? "No token"
            ], self.sendObjectCallback)
        numericParameter += 1
    }
    
    @IBOutlet weak var resultsLabel: UILabel!
}

