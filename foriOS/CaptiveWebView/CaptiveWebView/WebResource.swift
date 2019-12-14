// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
import MobileCoreServices
import os.log

public extension CaptiveWebView.WebResource {
    static func findFile(bundle: Bundle = Bundle.main,
                         name: String = "main.json",
                         results: [String]? = nil
        ) -> [String]
    {
        var found: [String] = results ?? []
        let paths: [String]
        do {
            paths = try FileManager.default.subpathsOfDirectory(
                atPath: bundle.bundlePath)
        } catch {
            os_log(OSLogType.error, "Failed to get subpaths at \"%@\". %@.",
                   bundle.bundlePath, error.localizedDescription)
            paths = []
        }
        
        for path in paths {
            let url = URL(fileURLWithPath: path)
            if url.lastPathComponent == name {
                found.append(path)
            }
        }
        
        return found
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
