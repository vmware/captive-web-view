// Copyright 2020 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

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
    if (value !== null && typeof value === 'object' && !Array.isArray(value)) {
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
        keySummary.type === "" ? keySummary.storage : keySummary.type
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

        this._page = new PageBuilder('div', undefined, document.body);
        this._build_key_store_panel();
        this._build_add_key_panel();
        this._build_button_panel();
        this._build_result_panel();
        this._transcript = this._page.add_transcript(true);
        this._transcript.node.classList.remove('cwv-transcript');

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
        const builder = new PageBuilder(this._page.add_node('fieldset'));
        const legend = builder.add_node('legend');

        const panel = { display: builder.add_node('textarea') };

        const resultIdentifier = "result";
        Object.entries({
            id:resultIdentifier, name:resultIdentifier, readonly:true,
            rows: 10, cols:45,
            placeholder:"No results yet ..."
        }).forEach(([key, value]) => panel.display.setAttribute(key, value));
        
        const label = PageBuilder.add_node('label', "Results", legend);
        label.setAttribute('for', resultIdentifier);
        // Default in the iOS web view is to select the textarea, and zoom in.
        // That isn't wanted here, so suppress it.
        label.addEventListener('click', event => event.preventDefault());

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
        const panel = { entries: [] };

        panel.emptyMessage = this._page.add_node('div', "Key store empty");
        panel.emptyMessage.classList.add('kst__key-store-message');

        panel.entriesNode = this._page.add_node('div');

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
            `Key ${index + 1}:`, ...key_item_labels(summary)
        ].join("");
        builder.add_node('legend', legend);

        const divButtons = new PageBuilder(builder.add_node('div'));
        const divControls = new PageBuilder(builder.add_node('div'));
        const buttons = [
            divButtons.add_button(), divButtons.add_button("Test")];

        const controls = [

            this._build_key_details_controls(
                buttons[0], divControls, summary, index),

            this._build_key_test_controls(divControls, summary.name, index)

        ];
        const collapsedClass = 'kst__key-controls_collapsed';
        controls.forEach(control => control.classList.add(
            'kst__key-controls', collapsedClass));
        buttons.forEach((buttonBuild, buttonIndex) => {
            buttonBuild.classList.add(
                'kst__key-button', 'kst__key-button_collapsed');
            
            buttonBuild.addEventListener('click', () => {
                const collapsed = controls[buttonIndex].classList.contains(
                    collapsedClass);

                buttons.forEach(
                    (button, clickedIndex) => button.classList.toggle(
                        'kst__key-button_collapsed',
                        (clickedIndex != buttonIndex) || !collapsed)
                );

                controls.forEach(
                    (control, controlIndex) => control.classList.toggle(
                        collapsedClass,
                        (controlIndex != buttonIndex) || !collapsed
                    )
                );
            })
        });

        return builder;
    }

    _build_key_details_controls(button, builder, summary, index) {
        const label = PageBuilder.add_node('label', "Details", button);

        const textarea = builder.add_node('textarea');
        const identifier = `key-details-${index}`;
        Object.entries({
            id:identifier, name:identifier, 
            readonly:true, rows: 10, cols:50
        }).forEach(([key, value]) => textarea.setAttribute(key, value));
        textarea.textContent = JSON.stringify(summary, undefined, 4);
        label.setAttribute('for', identifier);
        // Default in the iOS web view is to select the textarea, and zoom in.
        // That isn't wanted here, so suppress it.
        label.addEventListener('click', event => event.preventDefault());

        return textarea;
    }

    _build_key_test_controls(builder, alias, index) {
        const identifier = `key-test-${index}`;
        const testPanel = new PageBuilder(builder.add_node('div'));

        const sentinelInput = testPanel.add_input(
            identifier, "Sentinel:", true, "text");
        sentinelInput.inputNode.setAttribute('size', 6);

        const runButton = testPanel.add_button("Run");
        runButton.setAttribute('disabled', true);

        sentinelInput.inputNode.addEventListener('input', () => {
            if (sentinelInput.value.length > 0) {
                runButton.removeAttribute('disabled');
            }
            else {
                runButton.setAttribute('disabled', true);
            }
        });

        runButton.addEventListener('click', () => this._send({
            command: "encrypt", parameters: {
                sentinel: sentinelInput.value,
                alias: alias
            }
        }));

        return testPanel.node;
    }

    _build_add_key_panel() {
        const builder = new PageBuilder(this._page.add_node('fieldset'));
        builder.add_node('legend', "Add Key");

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
        const builder = new PageBuilder(this._page.add_node('div'));
        builder.node.classList.add('kst__button-panel');

        const refreshButton = builder.add_button("Refresh");
        refreshButton.addEventListener(
            'click', () => this._send({"command": "summariseStore"}));

        const capButton = builder.add_button("Capabilities");
        capButton.addEventListener(
            'click', () => this._send_for_results("capabilities"));

        const clearButton = builder.add_button("Delete All");
        clearButton.addEventListener(
            'click', () => this._send_for_results("deleteAll", true));
        
        const webViewKeyButton = builder.add_button("Store Web View Key");
        webViewKeyButton.addEventListener(
            'click', () => this._generate_web_view_key());
    }

    _send_for_results(command, update) {
        this._send({command: command})
        .then(response => {
            if (response.command === undefined) {
                response.command = command;
            }
            this.result = response;
            if (update) {
                this._send({command: "summariseStore"});
            }
            return response;
        });
    }

    _generate_web_view_key() {
        new Promise((resolve, reject) => {
            const crypto = window.crypto.subtle;
            if (crypto) {
                resolve(crypto);
            }
            else {
                reject(`Subtle Crypto: ${crypto}.`);
            }
        })
        .then(crypto =>
            crypto.generateKey({
                name: "RSA-OAEP",
                modulusLength: 4096,
                publicExponent: new Uint8Array([1, 0, 1]),
                hash: "SHA-256"
            }, false, ["encrypt", "decrypt"])
        )
        .catch(error => this._transcribe({"error": String(error)}))
        .then(keyPair => {
            this._transcribe(JSONable(keyPair, 1));
            return new Promise((resolve, reject) => {
                const name = "Keys";
                const request = indexedDB.open(name, 1);
    
                request.onerror = event => reject({
                    store: "open error", event: String(event)
                });
    
                // Create the schema, if needed.
                request.onupgradeneeded = event =>
                    event.target.result.createObjectStore(
                        name, {keyPath: "identifier"});
            
                // The resolve and reject functions are passed as parameters so
                // that the _store_key method can finalise the Promise.
                request.onsuccess = event => 
                    this._store_key(resolve, reject, event, keyPair);
            });
        })
        .then(result => {
            this._transcribe(result);
            this._send({"command": "summariseStore"});
        })
        .catch(error => this._transcribe(error));
    }

    _store_key(resolve, reject, eventOpen, keyPair) {
        const dataBase = eventOpen.target.result;
        const transaction = dataBase.transaction(dataBase.name, "readwrite");
        const store = transaction.objectStore(dataBase.name);

        try {
            // If you comment out the identifier key and value, in order to
            // generate an error, the .put will throw immediately instead of
            // invoking its onerror handler.
            const putRequest = store.put({"identifier":1, "key":keyPair});

            putRequest.onerror = domException => reject({
                store: "put error",
                code: domException.code,
                message: domException.message,
                name: domException.name,
                domException: String(domException)
            });
            putRequest.onsuccess = event => resolve({
                store: "OK", result: event.target.result
            });
        }
        catch(exception) {
            reject({
                store: "caught error",
                code: exception.code,
                message: exception.message,
                name: exception.name,
                exception: String(exception)
            });
        }
    }

    _send(command) {
        return this._bridge.sendObject(command)
        .then(response => {
            if (
                command.command === "summariseStore" &&
                response.keyStore !== undefined
            ) {
                // Setter invocation that reloads the key store items UI.
                this.keyStore = response.keyStore;
            }
            else {
                this._transcribe(response);
            }
            return response;
        });
    }

    _transcribe(message) {
        if ('secure' in message && !message['secure']) {
            // The `secure` item is a vestige of something Jim was trying in
            // relation to WebRTC in iOS. It's always false, which is maybe
            // worrying so remove it before transcribing here.
            delete message['secure'];
        }
        this._transcript.add(JSON.stringify(message, undefined, 4), 'pre');
    }
}

export default function(bridge) {
    PageBuilder.add_css_file("keystore.css");
    new KeyStore(bridge);
    return null;
}
