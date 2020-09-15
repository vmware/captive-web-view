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

function sorting_replacer(omit, key, value) {
    // TOTH: https://stackoverflow.com/a/31102605/7657675
    if (value !== null && typeof value === 'object') {
        const _return = {};
        Object.keys(value).filter(
            objectKey => !(key === "" && omit.includes(objectKey))
        ).sort().forEach(
            key => _return[key] = value[key]
        );
        return _return;
    }
    return value;
}

class KeyStore {
    constructor(bridge) {
        this._bridge = bridge;

        const page = new PageBuilder('div', undefined, document.body);
        const capButton = page.add_button("Capabilities");
        capButton.addEventListener('click', () => this._send(
            {command: "capabilities"}, true));

        this._resultPanel = this._build_result_panel();

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



        const buttonGenerateKey = this._add_button(
            'Generate Native Key "JS1"', () => this._send(
                {"command": "generateKey", "parameters": {"alias": "JS1"}}));

        const buttonGeneratePair = this._add_button(
            'Generate Native Pair "JS"', () => this._send(
                {"command": "generatePair", "parameters": {"alias": "JS"}}));

        const buttonDump = this._add_button(
            "Dump Key Store", () => this._send({"command": "dump"}));

        const buttonDeleteAll = this._add_button(
            "Delete All Keys", () => this._send({"command": "deleteAll"}));
        
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
            buttonGenerateKey, buttonGeneratePair, buttonDump, buttonDeleteAll,
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

    _build_result_panel() {
        const panel = {
            builder: new PageBuilder('div', undefined, document.body)
        };

        const resultIdentifier = "result";
        panel.display = panel.builder.add_node('textarea');
        Object.entries({
            id:resultIdentifier, name:resultIdentifier, readonly:true,
            rows: 10, cols:50,
            placeholder:"No results yet ..."
        }).forEach(([key, value]) => panel.display.setAttribute(key, value));

        panel.writeButton = panel.builder.add_button("Write");
        panel.writeButton.setAttribute('disabled', true);
        panel.writeButton.addEventListener('click', event => {
            this._send({command: "write", parameters: {
                text: this._resultPanel.display.textContent,
                filename: this._result.command + ".json"
            }});
            event.target.setAttribute('disabled', true);
        });

        return panel;
    }

    get result() { return this._result; }
    set result(result) {
        this._result = result;
        this._resultPanel.display.textContent = JSON.stringify(
            result,
            sorting_replacer.bind(this, ['command', 'confirm']),
            4
        );
        this._resultPanel.writeButton.removeAttribute('disabled');
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

    _send(command, setResult) {
        return this._bridge.sendObject(command)
        .then(response => {
            if (setResult) {
                if (response.command === undefined) {
                    response.command = command.command;
                }
                this.result = response;
            }
            else {
                this._transcribe(response);
            }
        });
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
