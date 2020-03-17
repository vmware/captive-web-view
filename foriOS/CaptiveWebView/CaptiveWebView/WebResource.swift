// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import MobileCoreServices
import os.log

public extension CaptiveWebView.WebResource {
    static func findFile(under: URL = Bundle.main.bundleURL,
                         tailComponents: [String],
                         results: [String]? = nil
    ) -> URL?
    {
        let resolvedUnder = under.resolvingSymlinksInPath()

        // options:.producesRelativePathURLs would have saved all the code to
        // generate a relative path, below, but:
        //
        //   'producesRelativePathURLs' is only available in application
        //   extensions for iOS 13.0 or newer
        //
        // There are other enumeration options in FileManager. If this one stops
        // working, for example because of a tricky symbolic link situation,
        // then try one of the others.

        guard let pathEnumerator = FileManager.default.enumerator(
            at: resolvedUnder,
            includingPropertiesForKeys: nil, options: [], errorHandler: nil
            ) else
        {
                return nil
        }
        
        for case let pathURL as URL in pathEnumerator {
            let pathComponents = pathURL.pathComponents
            // First component will be "/" but that'll be the only / in there.

            // Check if the pathURL has the required tail components.
            var pathIndex = pathComponents.count - 1
            var tailIndex = tailComponents.count - 1
            while tailIndex >= 0 {
                if pathIndex < 0 {
                    // Path ran out before matching everything.
                    break
                }
                if pathComponents[pathIndex] != tailComponents[tailIndex] {
                    break
                }
                // This component matches; check the next one.
                pathIndex -= 1
                tailIndex -= 1
            }

            if tailIndex < 0 {
                // https://developer.apple.com/documentation/foundation/nsurl/1415965-resolvingsymlinksinpath
                // "If the name of the receiving path begins with /private, this
                // property strips off the /private designator, provided the
                // result is the name of an existing file."

                let underComponents = resolvedUnder.pathComponents
                let returnComponents =
                    pathURL.resolvingSymlinksInPath().pathComponents
                
                var underIndex = underComponents.startIndex
                var returnIndex = returnComponents.startIndex
                while
                    underIndex < underComponents.endIndex,
                    returnIndex < returnComponents.endIndex
                {
                    if underComponents[underIndex] ==
                        returnComponents[returnIndex]
                    {
                        underIndex = underIndex.advanced(by: 1)
                        returnIndex = returnIndex.advanced(by: 1)
                    }
                    else {
                        break
                    }
                }
                
                // URL(fileURLWithPath:relativeTo:) seems to be the only
                // constructor that results in a file URL with a base URL.
                //
                // If the first parameter is the empty string, the resulting URL
                // always has a "." component there. It can be removed by
                // standardizing but that also seems to remove the base URL, and
                // hence the relative path with be an absolute path.
                //
                // The code here solves that by constructing with the first of
                // the return components, then appending each of the rest.
                //
                // That can't be done if there are no components, i.e. if the
                // return path is the same as the `under` URL. In that case,
                // return a URL with a "." component; there's no alternative.

                if returnIndex >= returnComponents.endIndex {
                    return URL(fileURLWithPath: "", relativeTo: resolvedUnder)
                }
                
                var returnURL = URL(
                    fileURLWithPath: returnComponents[returnIndex],
                    relativeTo: resolvedUnder)
                returnComponents[returnIndex.advanced(by: 1)...].forEach {
                    returnURL.appendPathComponent($0)
                }
                return returnURL
            }
        }
        
        return nil
    }

    static func getMIMEType(_ fileURL:URL) throws -> String {
        // TOTH:
        // https://stackoverflow.com/questions/31243371/path-extension-and-mime-type-of-file-in-swift#comment80791976_40003309
        
        guard let fileExtension:CFString = fileURL.pathExtension as CFString? else {
            throw URLSchemeTaskError("No file extension in " +
                String(describing: fileURL))
        }
        
        guard let utiString = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, fileExtension, nil)?
            .takeRetainedValue() else
        {
            throw URLSchemeTaskError("Null type identifier")
        }
        
        // Following code to get the UTI seems nicer but relies on there being a
        // real file. This function is also called with a made-up URL, like
        // file:/body.json, to get a proper MIME type for JSON data.
        //
        //     let values = try fileURL.resourceValues(forKeys:[.typeIdentifierKey])
        //     guard let utiString:String = values.typeIdentifier else {
        //         throw URLSchemeTaskError("null type identifier")
        //     }

        guard let mimeType = UTTypeCopyPreferredTagWithClass(
            utiString, kUTTagClassMIMEType)?.takeRetainedValue() else
        {
            throw URLSchemeTaskError("Null MIME type")
        }
        
        return mimeType as String
    }
    
    static func bodyFrom(request:URLRequest) -> Dictionary<String, Any>? {
        guard let bodyData = request.httpBody else {
            return nil
        }

        let bodyObject: Any
        do {
            bodyObject = try JSONSerialization.jsonObject(
                with: bodyData,
                options: JSONSerialization.ReadingOptions.allowFragments)
        }
        catch {
            return nil
        }
        return bodyObject as? Dictionary<String, Any> 
    }
}
