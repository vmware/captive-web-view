// Copyright 2020 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

class CaptiveCrypto {
    constructor(bridge) {
        const loading = document.getElementById('loading');
        this._bridge = bridge;

        const builder = new PageBuilder('div', undefined, document.body);
        builder.add_anchor("SubtleCrypto.html", "HTML 5 Subtle Crypto");
        builder.add_anchor("KeyStore.html", "Native Key Store");

        loading.firstChild.textContent = "Captive Cryptography";
    }
}

export default function(bridge) {
    new CaptiveCrypto(bridge);
    return null;
}
