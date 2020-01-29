Headless Sample
===============
The Headless sample application demonstrates running JavaScript Fetch HTTP
requests in a hidden web view. The sample is part of the Captive Web View
project. For an introduction to the project, see the [parent directory](/../)
readme file.

The sample demonstrates use of two APIs:

-   SWAPI: [https://swapi.co](https://swapi.co)

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

-   Swift source for iOS: [../foriOS/Headless/](../foriOS/Headless/)

    This sample is included in the Demonstration Xcode workspace, in the parent
    directory, and that might be the easiest way to build it. If you make a copy
    for your own work, refer to the general instructions in the
    [../foriOS/](../foriOS/) readme for how to add the Captive Web View
    framework.

-   JavaScript shared source: [../forAndroid/Headless/src/main/assets/WebResources/](../forAndroid/Headless/src/main/assets/WebResources/)

    There is an HTML file to facilitate loading. The JavaScript will create a
    testing user interface in the HTML, but this is only to facilitate
    development. The testing user interface can be loaded in a browser, or shown
    in a web view that isn't hidden.

    The headless part is in the _execute() method.

Secrets
=======
Use of the Go Rest API requires an access token, for authentication.

You can get an access token by registering, then opening this page:  
[https://gorest.co.in/user/settings/api-access.html](https://gorest.co.in/user/settings/api-access.html)

You could paste the access token into your copy of the Headless sample Kotlin or
Swift code, wherever you see a `token` parameter being sent to the web view.
However, there is a better way.

Create a file here:  

    /path/where/you/cloned/captive-web-view/forAndroid/Headless/src/main/assets/WebResources/secrets.js

Paste in the following:

    export default {
        "token": "yourGoRestTokenGoesHere"
    }

That makes your token available, indirectly, to the Kotlin and Swift code. The
path of the file is already configured to be ignored by Git.

Legal
=====
Copyright 2019 VMware, Inc.  
SPDX-License-Identifier: BSD-2-Clause
