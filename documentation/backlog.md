Backlog
=======
This is the product backlog for the Captive Web View library. For an
introduction, see the [parent directory](/../) readme file.

-   Dark mode support.

    -   For pagebuilder and app CSS in general, see:  
        https://developer.mozilla.org/en-US/docs/Web/CSS/@media/prefers-color-scheme

        If it works, set different values for the palette near here:  
        https://github.com/vmware/captive-web-view/blob/456faf670552ffbe35b6e892f8b6874a728c392b/forAndroid/captivewebview/src/main/assets/library/pagebuilder.css#L35
    
    -   For iOS, also see:

        -   User interface colour specification that will change for dark mode
            selection:  
            https://developer.apple.com/documentation/uikit/uicolor/3173140-systembackground

        -   One place that the colour should be applied:  
            https://github.com/vmware/captive-web-view/blob/master/forApple/CaptiveWebView/CaptiveWebView/ViewController.swift#L21

    -   For Android, TBD but definitely the pagebuilder and CSS change, above,
        and maybe in the Android Manifest files for the sample applications, in
        the `application` tag, set the `android:theme` attributes to a theme
        with built-in support.

        In another project, see:  
        https://github.com/vmware-samples/workspace-ONE-SDK-integration-samples/blob/main/IntegrationGuideForAndroid/Apps/baseKotlin/src/main/res/values/styles.xml

-   Error displays for iOS web View like the Android htmlErrorResponse().

    Calling iOS urlSchemeTask.didFailWithError aborts retrieval without showing
    any error in the WKWebView. That's OK for resources but for navigation means
    that there is no visible failure in the web view.

-   Add the meta in JS:

        <meta name="viewport" content="width=device-width, initial-scale=1.0">
    
    Currently it's in the HTML.

-   Construct HTML head fields programmatically, maybe.

-   Maybe a version with automatic scroll-into-view on focus.

    https://developer.mozilla.org/en-US/docs/Web/API/Element/scrollIntoView

-   Check if anything from the following code could be used:

    https://github.com/googlearchive/chromium-webview-samples/tree/master/webrtc-example/app/src/main/java/com/google/chrome/android/webrtcsample

Legal
=====
Copyright 2020 VMware, Inc.  
SPDX-License-Identifier: BSD-2-Clause
