// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

// Swift seems to have made it rather difficult to create a throw-able that
// has a message that can be retrieved in the catch. So, there's a custom
// class here.
//
// Having created a custom class anyway, it seemed like a code-saver to pack
// it with convenience initialisers for an array of strings, variadic
// strings, CFString, and OSStatus.

public class StoredKeyError: Error, CustomStringConvertible {
    let _message:String
    
    public init(_ message:String) {
        self._message = message
    }
    public convenience init(_ message:[String]) {
        self.init(message.joined())
    }
    public convenience init(_ message:String...) {
        self.init(message)
    }
    public convenience init(_ message:CFString) {
        self.init(NSString(string: message) as String)
    }
    public convenience init(_ osStatus:OSStatus, _ details:String...) {
        self.init(details.inserting(osStatus.secErrorMessage, at: 0))
    }
    
    public var message: String {
        return self._message
    }
    
    public var localizedDescription: String {
        return self._message
    }
    
    public var description: String {
        return self._message
    }
}

// Handy extension to get an error message from an OSStatus.
public extension OSStatus {
    var secErrorMessage: String {
        return (SecCopyErrorMessageString(self, nil) as String?) ?? "\(self)"
    }
}

