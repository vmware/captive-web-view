// Copyright 2020 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

const crypto = window.crypto.subtle;

function JSONable(obj, minLayers=0) {
    if (minLayers <= 0) {
        const stringified = JSON.stringify(obj);
        if (stringified !== "{}") {
            // console.log(stringified);
            return obj;
        }
    }
    const jsonAble = {};
    for(let propertyName in obj) {
        // console.log(propertyName, obj[propertyName]);
        jsonAble[propertyName] = JSONable(obj[propertyName], minLayers - 1);
    }
    return jsonAble;
}

class KeyStore {
    constructor(bridge) {
        this._bridge = bridge;
        this._transcript = document.createElement('div');

        const cryptoButtons = [];
        if (crypto) {
            // Add button here.
            cryptoButtons.push( this._add_button(
                "Generate JS Key Pair", () => this._generate_key(
                    {name: "ECDSA", namedCurve: "P-384"},
                    false, ["sign", "verify"]
                )
            ));
        }
        else {
            const div = document.createElement('div');
            div.append(`Subtle Crypto: ${crypto}.`);
            document.body.append(div);
        }

        const buttonGeneratePair = this._add_button(
            'Generate Native Pair "JS"', () => this._send(
                {"command": "generatePair", "parameters": {"alias": "JS"}}));

        const buttonDump = this._add_button(
            "Dump Key Store", () => this._send({"command": "dump"}));

        const buttonDeleteAll = this._add_button(
            "Delete All Keys", () => this._send({"command": "deleteAll"}));
        
        // const buttonClose = this._add_button(
        //     "Close", () => this._send({"command": "close"}));

        this._buttonClear = this._add_button("Clear Transcript", () => {
            // TOTH https://stackoverflow.com/a/22966637/7657675
            const transcript = this._transcript.cloneNode(false);
            this._transcript.parentNode.replaceChild(
                transcript, this._transcript);
            this._transcript = transcript;
            this._buttonClear.setAttribute('disabled', true);
        });
        this._buttonClear.setAttribute('disabled', true);

        document.body.append(
            ...cryptoButtons, 
            buttonGeneratePair, buttonDump, buttonDeleteAll, //buttonClose,
            document.createElement('hr'), this._buttonClear, this._transcript
        );

        bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {"confirm": "KeyStore"});
        };

        this._send({"command": "dump"})
        .then(() => {
            const loading = new PageBuilder(document.getElementById('loading'));
            loading.node.firstChild.remove();
            const anchor = loading.add_anchor(
                "Main.html", "Key Store Inspector");
            anchor.classList.add("cwv-anchor", "cwv-anchor_back");
        });
    }

    _add_button(label, onClick) {
        const button = document.createElement('button');
        button.type = 'button';
        button.append(label);
        button.addEventListener('click', onClick);
        return button;
    }

    _generate_key(...parameters) {
        return crypto.generateKey(...parameters).then(key => {
            this._transcribe(JSONable(key, 1));
            return key;
        })
        .catch(error => this._transcribe({"error": String(error)}));
    }

    _send(command) {
        return this._bridge.sendObject(command)
        .then(response => this._transcribe(response));
    }

    _transcribe(message) {
        const pre = document.createElement('pre');
        if ('secure' in message && !message['secure']) {
            // The `secure` item is a vestige of something Jim was trying in
            // relation to WebRTC in iOS. It's always false, which is maybe
            // worrying so remove it before transcribing here.
            delete message['secure'];
        }
        pre.append(JSON.stringify(message, undefined, 4));
        this._transcript.append(pre);
        this._buttonClear.removeAttribute('disabled');
    }
}

export default function(bridge) {
    new KeyStore(bridge);
    return null;
}
