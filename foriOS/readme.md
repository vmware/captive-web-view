
**Notes only for now, sorry**

Compatibility
=============
This code is compatible with the following software versions.

Software | Instructions last tested | Built
---------|--------------------------|-------
Xcode    | 10.2.1                   | 11.4.1

How to get the framework
==========================
1.  Download the code in the repository that contains this file.

    This project has some **case-sensitive file names**. This means that it may
    be a good idea to switch off case sensitivity in the Git configuration. See:
    [https://stackoverflow.com/a/37844763/7657675](https://stackoverflow.com/a/37844763/7657675)

2.  In Xcode, select to open the following path.

    /wherever/you/cloned/captive-web-view/foriOS/Demonstration.xcworkspace

    This is an Xcode workspace with two projects:

    -   Captivity, an excessive demonstration application.
    -   Skeleton, a minimal application.
    -   CaptiveWebView, the framework.

3.  Build the CaptiveWebView framework, and then the Captivity application.

You might need to remove the framework from the application and add it back to
make it build. You can do this either by dragging and dropping, or by clicking
the plus and minus buttons in the target build phases.

In the Xcode workspace view, there should now be a CaptiveWebView.framework item
in the CaptiveWebView Products folder.

How to make a new application that uses the framework
=====================================================
These instructions assume you have already have the framework, see under How to
get the framework, above.

1.  Open Xcode and create a new application project.

    -   Select Single View App as the template.
    -   Select Language: Swift.

    Build the project before going further just to check it works.

2.  Add the framework project.

    There are a couple of ways to do this that have worked in the past and might
    work for you:

    -   Add the CaptiveWebView project as a sub-project to your new application
        project.
    -   Create a new Xcode workspace in which your new application project and
        the CaptiveWebView project are peers.
    
    You can add projects as sub-projects, or to a workspace, by dragging and
    dropping. This web page has more instructions that might help:

    [https://developer.apple.com/library/archive/technotes/tn2435/_index.html](https://developer.apple.com/library/archive/technotes/tn2435/_index.html)

3.  Add the framework library to the application.

    1.  Open your application's target Build Phases.
    2.  Expand the Link Binary With Libraries section.
    3.  Either drag and drop the CaptiveWebView.framework item from the
        CaptiveWebView Products into the section, or click the plus button and
        add it from the Workspace in the dialog.
    4.  Expand the Embed Frameworks section and add the same item to this list
        also.
    
    Build the application to check that this still works. If it doesn't, you
    might be able to fix it by removing and re-adding the framework, either in
    the target Build Phases, as above, or in the target General tab.

4.  Change the application ViewController to be based on a Captive Web View.

    Open the ViewController.swift file in Xcode and make the following changes.

    1.  Import the module, for example by adding a line like:

            import CaptiveWebView

    2.  Change the ViewController to a subclass of the default view controller
        class in the module, for example by changing the declaration to:

            class ViewController: CaptiveWebView.DefaultViewController {
            ...
            }

    The default view controller is a higher-level interface that simplifies
    implementation of a Captive Web View application.

    You can delete the viewDidLoad method from your ViewController class.

5.  Set the name of the HTML file to load in your view controller.

    Choose a name, like `Main.html` and then do **either** of the following, but
    not both.

    -   Open the ViewController.swift file in Xcode and override the computed
        value for the `mainHTML` property, for example as follows.

            override var mainHTML: String { return "Main.html" }
    
    -   Rename the ViewController class to MainViewController.

        The Xcode IDE facilitates renaming a class as a type of refactoring.
        **Be careful** you don't change anything in the Captive Web View
        framework. For example, unselect those incidences in the Xcode rename
        confirmation screen.

        Xcode mightn't actually change the name of the ViewController.swift
        file, even if you select to do so. If that happens, exit Xcode and
        rename the file by hand.
    
    What's happening behind the scenes:  
    The Captive Web View framework includes a ViewController base class, one
    level below the DefaultViewController. The base class has the code that
    loads the web content into a WKWebView, starting with an HTML file. By
    default, it generates the HTML file name from the ViewController subclass
    name. Generation consists of deleting the suffix "ViewController". So, you
    can either rename your ViewController class or override the default
    behaviour.

6.  Create the HTML file.

    If you have already created a corresponding Android application that will
    have the same user interface, then skip this step.

    It can be tidy to have a dedicated sub-directory, for example named
    `UserInterface`, just for your user interface web resources. This also
    facilitates sharing the files with an Android application if you create one
    later. Create the sub-directory by hand, under the application project
    directory.

    In a text editor, or in Xcode, create a file in the sub-directory. In the
    preceding step, `Main.html` was the suggested name. Note the initial
    capital.

    Copy and paste the following HTML code into the file, or copy the
    UserInterface/Main.html file from the Skeleton application in the
    Demonstration workspace in the repository.

        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                body {font-family: sans-serif;}
            </style>
        </head>
        <body
        ><script src="captivewebview.js"></script
        ><script>
            CaptiveWebView.whenLoaded("main.js");
        </script
        ><h1 id="loading">Loading ...</h1
        ></body>
        </html>

    There are two script tags, one for the Captive Web View bridge
    initialisation, `captivewebview.js`, the other for your code `main.js` in
    this example. The HTML is written in a whitespace elimination style, i.e.
    with no space in between an end tag and the start of the next tag.

7.  Add the web resources to the application.

    If you created a UserInterface/ sub-directory in the previous step, or if
    you skipped the previous step because you already have one in an Android
    project, then add the sub-directory now. You can do this in Xcode, as
    follows.

    1.  Right-click the application folder, which may be the first level under
        the application project. Then select the option to Add Files to "..."
        ... in the context menu that drops down.
    2.  In the dialog that appears, highlight the user interface directory and
        select the option to Create folder references. Don't select to copy
        items.
    3.  Click Add.

    The sub-directory should now appear under the application's folder. It
    should have a blue folder icon. If it doesn't, remove it and try again.

    If you expand the blue folder, you should see the contents of the directory,
    including the Main.html file if you called it that.

    Note for sharing files with an Android project:  
    Android applications are build with Gradle, which seems to work best when
    all files are under one umbrella directory. For this reason, you might find
    it easier to have the real files in the Android project directory, and a
    reference to that directory from the Xcode project.  
    This is how the Captive Web View repository is structured. For example, real
    web resource files are in the
    captive-web-view/forAndroid/Captivity/src/main/assets/UserInterface/
    directory; a reference to that directory appears in the Xcode project at
    Captivity/UserInterface.

8.  Create the JavaScript file.

    If you have already created a corresponding Android application that will
    have the same user interface, then skip this step.

    In a text editor, or in Xcode, create a new file in the same sub-directory
    as the HTML file you created earlier. The boilerplate HTML uses `main.js` as
    the name.

    Copy and paste the following JavaScript code into the file, or copy the
    UserInterface/main.js file from the Skeleton application in the
    Demonstration workspace in the repository.

        class Main {
            constructor(bridge) {
                const loading = document.getElementById('loading');

                this._transcript = document.createElement('div');
                document.body.append(this._transcript);

                bridge.receiveObjectCallback = command => {
                    this._transcribe(command);
                    return Object.assign(command, {"confirm": "Main"});
                };

                loading.firstChild.textContent = "Application Name";
                // ToDo: Change to the name of your application.

                bridge.sendObject({"command": "ready"})
                .then(response => this._transcribe(response))
                .catch(error => this._transcribe(error));
            }

            _transcribe(message) {
                const pre = document.createElement('pre');
                pre.append(JSON.stringify(message, undefined, 4));
                this._transcript.append(pre);
            }
        }

        export default function(bridge) {
            new Main(bridge);
            return null;
        }

9.  Run the application.

    At this point you should be able to build and run the application.

    The user interface will look like this:

    # Application Name

        {
            "failed": "Unknown command \"ready\"",
            "command": "ready"
        }

    This could also be a good opportunity to try out the Safari developer tools.
    
    -   Do an Internet search for "Safari developer tools" for basic information
        and instructions.
    -   You have to do something extra to enable the Safari developer tools to
        inspect the WKWebView in your application running on a device, as
        follows.

        1.  On the device, open Settings and navigate to Safari, Advanced.
        2.  Set the following both on: JavaScript, Web Inspector.

        You might have to restart Safari on your desktop, and on your device,
        and restart Xcode and re-install your application for the change to take
        effect.

10. Add the Swift end of the command handler.

    When you ran your application in the previous step, there was a failure
    message. This is because the JavaScript end sent a command, "ready", that
    the native Swift end didn't recognise. Now add a handler that recognises
    that command.

    1.  Open your view controller .swift file in Xcode.
    2.  In your view controller class, declare an override for the
        response:to:in: method.
    3.  Add a method body that returns an empty dictionary in response to the
        "ready" command, or delegates to its base class for other commands.
    
    The new method looks like this:

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

    The above code is also in the MainViewController.swift file in the Skeleton
    application in the Demonstration workspace in the repository.

11. Run the application again.

    The user interface will look like this:

    # Application Name

        {
            "command": "ready",
            "confirm": "MainViewController bridge OK."
        }

     Note that there is a round trip starting with a command object in the
     JavaScript layer that becomes a dictionary in the Swift layer, then a
     response dictionary in the Swift layer that becomes an object in the
     JavaScript layer.

This concludes the initial application build. The next step could be to:

-   Add more JavaScript code that builds an HTML5 user interface, inside the web
    view.
-   Add a native-to-JavaScript bridge, see below.
-   Remove the application storyboard, see below.

How to add a native-to-JavaScript bridge
========================================
The initial application build, see the previous section, has a
JavaScript-to-native bridge. The following instructions add a bridge in the
opposite direction.

You only need the opposite bridge if you have events or interactions that start
in the native layer. You don't need this bridge just to respond to commands from
the JS layer.

TBD properly but in note form:

1.  In the Demonstration workspace, in the Captivity application, Open the
    MainViewController.swift file.
2.  Look for the self.sendObject call.
3.  Copy it somewhere in your native code.

    The IndexViewController sends an object every time it receives a command,
    which is pointless but demonstrates the feature.

4.  The boilerplate JavaScript in the previous section already includes a
    handler for its end of the bridge. The handler:

    -   Prints the object that was sent, as a dictionary, from the native code.
    -   Adds a confirm attribute to the object and sends it back as a response.

    The IndexViewController doesn't do anything with the response object.

How to remove the application storyboard
========================================
TBD properly but in note form:

1.  Change your AppDelegate to be a subclass of the
    CaptiveWebView.ApplicationDelegate class, and then call self.launch like in
    the AppDelegate.swift code in the Captivity application in the workspace in
    the repository. Code is like this:

        self.launch(MainViewController.self)

2.  Remove the UIMainStoryboard setting from the Info.plist file.
3.  Remove the Main.storyboard file from the project.

Legal
=====
Copyright 2020 VMware, Inc.  
SPDX-License-Identifier: BSD-2-Clause
