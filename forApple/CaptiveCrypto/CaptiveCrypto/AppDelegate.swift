//
//  AppDelegate.swift
//  CaptiveCrypto
//
//  Created by Jim Hawkins on 07/09/2020.
//  Copyright © 2020 Jim Hawkins. All rights reserved.
//

import UIKit
import CaptiveWebView

@UIApplicationMain
class AppDelegate: CaptiveWebView.ApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        self.launch(MainViewController.self)
        
        return true
    }

}
