// Copyright 2020 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

class CaptiveCrypto {
    constructor(bridge) {
        const loading = document.getElementById('loading');
        this._bridge = bridge;

        loading.firstChild.textContent = "Captive Cryptography";
    }
}

export default function(bridge) {
    new CaptiveCrypto(bridge);
    return null;
}
