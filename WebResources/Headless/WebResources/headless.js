// Copyright 2020 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

class Headless {
    constructor(bridge) {
        this._bridge = bridge;

        this._token = this._add_input(
            'Token', "Paste in your go-rest Access Token");

        document.body.append(document.createElement('hr'))

        this._add_button('SWAPI', () => this._execute({
            api:'star-wars', path:['people', 3]
        }));
        this._add_button('go-rest 401', () => this._execute({
            api:'go-rest', path:['users', 19]
        }));
        this._add_button('go-rest query parameter', () => this._execute({
            api:'go-rest', path:['users', 21],
            'query-parameter': 'access-token',
            'token': this._token.value
        }));
        this._add_button('go-rest basic', () => this._execute({
            api:'go-rest', path:['users', 20], 'basic-auth': 'Bearer',
            'token': this._token.value
        }));

        this._bridge.receiveObjectCallback = command => Object.assign(
            this._execute(command), {"confirm": "Main"});

        this._hr = document.createElement('hr');
        document.body.append(this._hr);

        import("./secrets.js")
        .then(secrets => {
            this._token.value = secrets.default.token;
            this._bridge.sendObject({"token": this._token.value});
        })
        .catch(error => {
            const message = `No secrets found ${error}`;
            this._transcribe({error:message});
            this._bridge.sendObject({"noToken": message});
        });

        document.getElementById('loading').firstChild.textContent = "Headless";
        this._bridge.sendObject({"command": "ready"})
        .then(response => this._transcribe(response));

        this._token.focus();
    }

    _add_input(label, title) {
        const form = document.createElement('form');

        const element = document.createElement('input');
        element.setAttribute('name', label);
        element.setAttribute('type', 'password');
        element.setAttribute('placeholder', title);
        element.setAttribute('size', title.length + 4);
        element.setAttribute('autocomplete', 'one-time-code');

        const labelElement = document.createElement('label');
        labelElement.append(`${label}:`);
        labelElement.setAttribute('for', label);

        form.append(labelElement, element);
        document.body.append(form);
        return element;
    }

    _add_button(label, listener) {
        const button = document.createElement('button');
        button.append(label);
        button.setAttribute('type', 'button');
        button.addEventListener('click', listener);
        document.body.append(button);
        return button;
    }

    _execute(command) {
        command.uri = [
            Headless.apis[command.api].prefix,
            command.path.join('/'),
            'query-parameter' in command ? 
            `?${command['query-parameter']}=${command.token}` :
            '',
            'suffix' in command ? command.suffix : '',
            Headless.apis[command.api].suffix
        ].join('');
        const headers = {'Content-Type': 'application/json'};
        if ('basic-auth' in command) {
            headers['Authorization'] =
            `${command['basic-auth']} ${command.token}`;
        }
        if ('headers' in command) {
            Object.apply(command.headers, headers);
        }
        else {
            command.headers = headers;
        }
        this._transcribe({executing:command});
        setTimeout(() => {
            // console.log('in time out for send.');
            fetch(command.uri, {method:'GET', headers:command.headers})
            .then(response => Promise.all([response, response.json()]))
            .then(([response, body]) => {
                // console.log(response, body)
                const result = {
                    ok:response.ok, body:body, status:response.status,
                    statusText:response.statusText
                };
                this._transcribe(result);
                this._bridge.sendObject(result);
            })
            .catch(error => {
                // console.log(error);
                const result = {error:`${error}`};
                this._transcribe(result);
                this._bridge.sendObject(result);
            });
        }, 0);
        // console.log('after time out.')

        return command;
    }

    _transcribe(result) {
        const pre = document.createElement('pre');
        pre.append(JSON.stringify(result, undefined, 4));
        this._hr.insertAdjacentElement('afterend', pre);
    }
}
Headless.apis = {
    'star-wars': {
        prefix: 'https://swapi.dev/api/',
        suffix: ''
    },
    'go-rest': {
        prefix: 'https://gorest.co.in/public-api/',
        suffix: ''
    }
};

export default function(bridge) {
    new Headless(bridge);
    return null;
}
