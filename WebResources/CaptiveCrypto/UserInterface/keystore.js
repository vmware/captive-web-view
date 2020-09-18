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

const prefix = "CaptiveCrypto ";
function key_item_labels(keySummary) {
    const name = (
        keySummary.name.startsWith(prefix)
        ? keySummary.name.slice(prefix.length)
        : keySummary.name
    );
    return [
        ...(name === "" ? [] : [' "', name, '" ']),
        keySummary.type === "" ? keySummary.store : keySummary.type
    ];
}

function key_sort_value(keySummary) {
    return [
        ...key_item_labels(keySummary),
        JSON.stringify(keySummary.summary, sorting_replacer.bind(null, []))
    ].join("");
}

class KeyStore {
    constructor(bridge) {
        this._bridge = bridge;

        this._build_key_store_panel();
        this._build_add_key_panel();
        this._build_button_panel();
        this._build_result_panel();

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

        const buttonDump = this._add_button(
            "Summarise Store", () => this._send({"command": "summariseStore"}));

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
            buttonDump,
            document.createElement('hr'), this._buttonClear, this._transcript
        );

        bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {"confirm": "KeyStore"});
        };

        this._send({"command": "summariseStore"})
        .then(() => {
            const loading = new PageBuilder(document.getElementById('loading'));
            loading.node.firstChild.remove();
            const anchor = loading.add_anchor("Main.html", "Key Store");
            anchor.classList.add("cwv-anchor", "cwv-anchor_back");
        });
    }

    _build_result_panel() {
        const builder = new PageBuilder('div', undefined, document.body);
        const panel = { display: builder.add_node('textarea') };

        const resultIdentifier = "result";
        Object.entries({
            id:resultIdentifier, name:resultIdentifier, readonly:true,
            rows: 10, cols:50,
            placeholder:"No results yet ..."
        }).forEach(([key, value]) => panel.display.setAttribute(key, value));

        panel.writeButton = builder.add_button("Write");
        panel.writeButton.setAttribute('disabled', true);
        panel.writeButton.addEventListener('click', event => {
            this._send({command: "write", parameters: {
                text: this._resultPanel.display.textContent,
                filename: this._result.command + ".json"
            }});
            event.target.setAttribute('disabled', true);
        });

        this._resultPanel = panel;
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

    _build_key_store_panel() {
        const builder = new PageBuilder('div', undefined, document.body);
        const panel = { entries: [] };
        builder.node.classList.add('kst__key-store');

        panel.emptyMessage = builder.add_node('div', "Key store empty.");
        panel.emptyMessage.classList.add('kst__key-store-message');

        panel.entriesNode = builder.add_node('div');

        this._keyStorePanel = panel;
    }

    get keyStore() { return this._keyStore; }
    set keyStore(keyStore) {
        this._keyStore = keyStore;

        const panel = this._keyStorePanel;
        panel.emptyMessage.classList.toggle(
            'kst__key-store-message_empty', keyStore.length <= 0);

        // Add a sort value for every key entry in the key store summary.
        const updatedEntries = keyStore.map(keySummary => {return {
            summary:keySummary, sortValue:key_sort_value(keySummary)
        }}).sort((a, b) => (
            a.sortValue < b.sortValue ? -1 : a.sortValue > b.sortValue ? 1 : 0
        ));

        // Cheeky use of .every() method. An early `return true` serves as a
        // continue would in a for loop.
        updatedEntries.every((storeEntry, index) => {
            const {summary, sortValue} = storeEntry;
            if (index >= panel.entries.length) {
                panel.entries.push(storeEntry);
            }
            else if (sortValue != panel.entries[index].sortValue) {
                panel.entries[index] = storeEntry;
            }
            else {
                // No change from incumbent.
                return true;
            }

            this._new_key_entry(summary, index);
            return true;
        });

        while(panel.entriesNode.children.length > updatedEntries.length) {
            panel.entriesNode.children[updatedEntries.length].remove();
        }
        panel.entries = updatedEntries;
    }

    _new_key_entry(summary, index) {
        const builder = new PageBuilder('fieldset');
        const parent = this._keyStorePanel.entriesNode;
        if (index >= parent.children.length) {
            parent.append(builder.node);
        }
        else {
            parent.children[index].replaceWith(builder.node);
        }
        const legend = [
            `${index + 1}`, ...key_item_labels(summary)
        ].join("");
        builder.add_node('legend', legend);
        const button = builder.add_button();
        const label = PageBuilder.add_node('label', "Details", button);
        const textarea = builder.add_node('textarea');
        textarea.classList.add(
            'kst__key-details', 'kst__key-details_collapsed');
        const identifier = `key-${index}`;
        Object.entries({
            id:identifier, name:identifier, 
            readonly:true, rows: 10, cols:50
        }).forEach(([key, value]) => textarea.setAttribute(key, value));
        textarea.textContent = JSON.stringify(summary, undefined, 4);
        label.setAttribute('for', identifier);
        button.addEventListener('click', () => {
            textarea.classList.toggle('kst__key-details_collapsed');
        });
        return builder;
    }

    _build_add_key_panel() {
        const builder = new PageBuilder('fieldset', undefined, document.body);
        builder.add_node('legend', "Add Key");
        // const panel = { entries: [] };
        const nameInput = builder.add_input('alias', "Alias:", true, "text");
        nameInput.inputNode.setAttribute('size', 6);
        nameInput.node.classList.add('kst__key-alias');

        const pairButton = builder.add_button("Key Pair");
        pairButton.addEventListener(
            'click', () => this._send_add_key("generatePair", nameInput));

        const keyButton = builder.add_button("Key");
        keyButton.addEventListener(
            'click', () => this._send_add_key("generateKey", nameInput));
    }

    _send_add_key(command, input) {
        this._send({command: command, parameters: {alias: input.value}})
        .then(response => {
            input.value = "";
            this._send({"command": "summariseStore"});
        });
    }

    _build_button_panel() {
        const builder = new PageBuilder('div', undefined, document.body);
        const capButton = builder.add_button("Capabilities");
        capButton.addEventListener(
            'click', () => this._send_for_results("capabilities"));

        const clearButton = builder.add_button("Delete All");
        clearButton.addEventListener(
            'click', () => this._send_for_results("deleteAll", true));
    }

    _send_for_results(command, update) {
        this._send({command: command})
        .then(response => {
            if (response.command === undefined) {
                response.command = command.command;
            }
            this.result = response;
            if (update) {
                this._send({command: "summariseStore"});
            }
            return response;
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
        .then(response => {
            if (command.command === "summariseStore") {
                this.keyStore = response.keyStore;
            }
            else {
                this._transcribe(response);
            }
            return response;
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
    PageBuilder.add_css_file("keystore.css");
    new KeyStore(bridge);
    return null;
}
