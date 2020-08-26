# Headless Sample
The Headless sample application demonstrates running JavaScript Fetch HTTP
requests in a hidden web view. The sample is part of the Captive Web View
project. For an introduction to the project, see the [parent directory](/../)
readme file.

The sample demonstrates use of two APIs:

-   SWAPI: [https://swapi.dev](https://swapi.dev)

    SWAPI is an API that provides data about the Star Wars universe. There is no
    user authentication.

-   Go Rest: [https://gorest.co.in](https://gorest.co.in)

    Go Rest is a free REST API for testing and prototyping. Registration is
    required. User authentication is then done by an access token. Details can
    be found on their home page.

There is a sample application for Android and for iOS. They share the same
JavaScript code. The source code is in this repository, in the following
locations.

-   Kotlin source project for Android: [../forAndroid/Headless/](../forAndroid/Headless/)

    The sample application is included in the Gradle project for Captive Web
    View, which is the easiest way to build it. If you make a copy for your own
    work, refer to the general instructions in the
    [../forAndroid/](../forAndroid/) readme for how to add the Captive Web View
    library.

-   Swift source for iOS: [../forApple/Headless/](../forApple/Headless/)

    This sample is included in the Demonstration Xcode workspace, in the parent
    directory, and that might be the easiest way to build it. If you make a copy
    for your own work, refer to the general instructions in the
    [../forApple/](../forApple/) readme for how to add the Captive Web View
    framework.

-   JavaScript shared source: [../WebResources/Headless/WebResources](../WebResources/Headless/WebResources/)

    There is an HTML file to facilitate loading. The JavaScript will create a
    testing user interface in the HTML, but this is only to facilitate
    development. The testing user interface can be loaded in a browser, or shown
    in a web view that isn't hidden.

    The headless part is in the _execute() method.

# API Issues
Some issues have been encountered with the APIs.

## HTTP Headers
The current version of the sample code doesn't include a content-type header in
requests to SWAPI. Earlier versions included a header like:

    Content-Type: application/json

This header appeared to cause an issue in recent versions of Chrome and the
Android Web View, as follows.

-   A request with this particular header and value is disqualified from being a
    "simple request", see [https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#Simple_requests](https://developer.mozilla.org/en-US/docs/Web/HTTP/CORS#Simple_requests).

-   Because the request isn't simple, a CORS preflight is triggered.

-   In response to the preflight, the SWAPI server redirects from its https
    server to its http server.

-   Chrome and the Android Web View don't allow redirect during preflight and
    fail the request at that stage.

The solution was to omit that header from SWAPI requests. The request then
qualifies as simple, a preflight isn't triggered, and the request continues.

## Mixed Content Security
SWAPI redirects from https to http when servicing requests.

The Captive Web View library for Android sets the protocol for content from the
application assets folder to https, by default. This is done so that the Android
web view recognises it as a secure context from which, for example, the
SubtleCrypto JavaScript interface can be used.

This combination means that SWAPI response content is of mixed security. By
default, the Android Web View treats this as an error.

This can be resolved by setting the most relaxed mixed-content mode, for example
with code like this:

    webView.settings.mixedContentMode =
        android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW

Setting the next most relaxed mode, MIXED_CONTENT_COMPATIBILITY_MODE, doesn't
seem to resolve this issue.






        <key>NSAllowsArbitraryLoadsInWebContent</key>
        <true/>



# Secrets
Use of the Go Rest API requires an access token, for authentication.

You can get an access token by registering, then opening this page:  
[https://gorest.co.in/user/settings/api-access.html](https://gorest.co.in/user/settings/api-access.html)

You could paste the access token into your copy of the Headless sample Kotlin or
Swift code, wherever you see a `token` parameter being sent to the web view.
However, there is a better way.

Create a file here:  

    /path/where/you/cloned/captive-web-view/WebResources/Headless/WebResources/secrets.js

Paste in the following:

    export default {
        "token": "yourGoRestTokenGoesHere"
    }

That makes your token available, indirectly, to the Kotlin and Swift code. The
path of the file is already configured to be ignored by Git.

Legal
=====
Copyright 2020 VMware, Inc.  
SPDX-License-Identifier: BSD-2-Clause
