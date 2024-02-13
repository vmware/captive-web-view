// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

import XCTest

import captive_web_viewTests

var tests = [XCTestCaseEntry]()
tests += CaptiveWebViewTests.allTests()
XCTMain(tests)
