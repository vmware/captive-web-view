Backlog
=======
This is the product backlog for the Captive Web View library. For an
introduction, see the [parent directory](/../) readme file.

-   The default for iPadOS seems to be to open a second ViewController in a kind
    of pop-over window. Fix that so it opens full screen like it does in iOS.

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

Legal
=====
Copyright 2019 VMware, Inc.  
SPDX-License-Identifier: BSD-2-Clause
