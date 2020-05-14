// Copyright 2019 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

import PageBuilder from "./pagebuilder.js";

class Spinner {
    constructor(bridge) {
        this._bridge = bridge;
        const loading = document.getElementById('loading');
        const builder = new PageBuilder('div', undefined, document.body);

        const top = new PageBuilder('div', undefined, builder.node);
        const middle = this._set_up(builder);
        const bottom = new PageBuilder('div', undefined, builder.node);

        bottom.add_node(
            'div', "This page loads in a separate Activity or ViewController.");
        bottom.add_node(
            'div', "Return by tapping Close, or the Android back button.");
        const buttonClose = bottom.add_button("Close");
        this._transcript = bottom.add_transcript(false);

        bridge.receiveObjectCallback = command => {
            this._transcribe(command);
            return Object.assign(command, {"confirm": "Spinner"});
        };

        buttonClose.addEventListener('click', () => this._send({
            "command": "close"}));

        loading.firstChild.textContent = "Spinner";
        top.into(loading);
        const spinnerSVG = document.getElementById('spinner-svg');
        top.into(spinnerSVG);


        this._send({"command": "ready"});
    }

    _set_up(builder) {
        const middle = new PageBuilder('div', undefined, builder.node);
        middle.node.setAttribute('id', 'spinner');

        const embed = middle.add_node('div', "Embed", middle.node);
        embed.setAttribute('id', 'embed');

        middle.add_node('span', "Spinner:", middle.node);
        const spinner = middle.add_node('div', undefined, middle.node);
        spinner.setAttribute('id', 'background-spinner');

        return middle;
    }

    _transcribe(message) {
        this._transcript.add(JSON.stringify(message, undefined, 4));
    }

    _send(object_) {
        return (
            this._bridge ?
            this._bridge.sendObject(object_) :
            Promise.reject(new Error("No Bridge!"))
        ).then(response => {
            this._transcribe(response);
            return response;
        })
        .catch(error => {
            this._transcribe(error);
            return error;
        });
    }
}

export default function(bridge) {
    new Spinner(bridge);
    return null;
}
