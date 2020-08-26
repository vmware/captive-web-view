// Copyright 2020 VMware, Inc.  
// SPDX-License-Identifier: BSD-2-Clause

class Headless {
    constructor(bridge) {
        this._bridge = bridge;

        this._token = this._add_input(
            'Token', "Paste in your go-rest Access Token");

        document.body.append(document.createElement('hr'))

        this._add_command_button('SWAPI', {
            api:'star-wars', path:['people', 3]
        });
        this._add_command_button('go-rest GET', {
            api:'go-rest', path:['users', 20]
        });
        this._add_command_button('go-rest 401', {
            method:"POST", api:'go-rest', path:['users']
        });
        // Query parameter isn't supported any more.
        //
        // this._add_command_button('go-rest query parameter', {
        //     method:"POST", api:'go-rest', path:['users'],
        //     'query-parameter': 'access-token'
        // });
        this._add_command_button('go-rest basic', {
            method:"POST", api:'go-rest', path:['users'], 'basic-auth': 'Bearer'
        });

        this._bridge.receiveObjectCallback = command => Object.assign(
            this._command(command), {"confirm": "Main"});

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

    _add_command_button(label, command) {
        const button = document.createElement('button');
        button.append(label);
        button.setAttribute('type', 'button');
        button.addEventListener('click', () => this._command(command));
        document.body.append(button);
        return button;
    }

    _command(command) {
        const request = this._build_request(command);
        command.url = request.url;
        this._transcribe({command:command});
        setTimeout(() => {
            this._request(request)
            .then(result => {
                this._transcribe(result);
                this._bridge.sendObject(result);
            });
        }, 0);
        // console.log('after time out.')

        return command;
    }

    _build_request(command) {
        const base = Headless.apis[command.api];

        const headers = new Headers(base.headers);
        [command.headers].filter(
            headerObject => headerObject !== undefined
        ).forEach(headerObject => {
            Object.entries(headerObject).forEach(
                ([key, value]) => headers.set(key, value)
            );
        });
        if ('basic-auth' in command) {
            headers.set(
                'Authorization',
                [command['basic-auth'], this._token.value].join(" ")
            );
        }

        const uri = new URL(document.URL);
        uri.protocol = base.protocol;
        uri.hostname = base.hostname;
        uri.port = "";
        uri.pathname = [...base.path, ...command.path].join('/');
        if ('query-parameter' in command) {
            uri.searchParams.append(
                command['query-parameter'], this._token.value);
        }
        if (command.parameters !== undefined) {
            Object.entries(command.parameters).forEach(
                ([key, value]) => uri.searchParams.append(key, value)
            );
        }

        const request = new Request(
            uri, {method: command.method, cache: 'no-cache', headers:headers});

        return request;
    }

    _request_JSON(request) {
        return {
            url: request.url, headers: [...request.headers.entries()]
        };
    }

    async _request(request) {
        let errorMessage;

        if (request.method === "GET") {
            return await this._fetch_JSON(request);
        }

        if (request.method === "POST") {
            const uri = new URL(request.url);
            if (
                (
                    uri.pathname.endsWith("/users") 
                    || uri.pathname.endsWith("/users/")
                )
                && uri.hostname === Headless.apis['go-rest'].hostname
             )  {
                return this._fetch_post_delete(request)
                .catch(error => {return {error:`${error}`}});
            }
            errorMessage = {
                message: "Unknown POST combination.",
                request: {pathname: uri.pathname, hostname: uri.hostname},
                known: {hostname: Headless.apis['go-rest'].hostname}
            };
        }

        if (errorMessage === undefined) {
            errorMessage = (
                request.method === undefined ? {
                    message: "No `method` ."
                } : {
                    message: "Unknown method.",
                    method: request.method
                }
            );
        }
        return {error:errorMessage, request:this._request_JSON(request)};
    }

    async _fetch_JSON(request) {
        let response;
        try {
            response = await fetch(request);
        }
        catch(error) {
            // console.log(error);
            return {
                error:`${error}`,
                request:this._request_JSON(request)
            };
        }

        if (!response.ok) {
            return {
                error: {
                    status: response.status,
                    statusText:response.statusText
                },
                request:this._request_JSON(request)
            }
        }

        try {
            return {
                ok:response.ok, body:await response.json(),
                status:response.status, statusText:response.statusText
            };
        }
        catch(error) {
            // console.log(error);
            return {
                error:`${error}`,
                request:this._request_JSON(request),
            };
        }

    }

    // _fetch_one(command, body) {
    //     const fetchOptions = {
    //         method:command.method,
    //         headers:command.headers,
    //         cache:"no-cache"
    //     };
    //     if (body !== undefined) {
    //         fetchOptions.body = body;
    //     }
    //     return fetch(command.uri, fetchOptions)
    //     .then(response => Promise.all([response, response.json()]));
    // }

    async _fetch_post_delete(request) {
        const userDetails = {
            name: 'Andy Warhol',
            email: 'andy@example.com',
            gender: 'Male',
            status: 'Inactive'
        };


        // return this._fetch_one(this._build_command({
        //     method:"GET", api:'go-rest', path:['users']
        // }))
        // .then(([response, body]) => {
        //     console.log('internal fetch', response, body);
        //     let matchingEmail = [];
        //     body.data.forEach(user => {
        //         console.log(user.email);
        //         if (user.email === userDetails.email) {
        //             matchingEmail.push(user.id);
        //         }
        //     });
        //     console.log('Matching email user identifiers:', matchingEmail);



        const userBlob = new Blob(
            [JSON.stringify(userDetails, null, 2)],
            {type : 'application/json'}
        );
        console.log('posting', userDetails);

        const firstRequest = new Request(request, {body: userBlob});
        let response = await this._fetch_JSON(firstRequest);
        console.log(response);

        if (response.body.code === 422) {
            await this._delete_matches(request, userDetails);
            const secondRequest = new Request(request, {body: userBlob});
            response = await this._fetch_JSON(secondRequest);
        }

        if (response.body.code < 200 || response.body.code >= 300) {
            return {error: response, request: this._request_JSON(firstRequest)};
        }

        // User entry was created OK. Delete it so that the email address isn't
        // in use and the create can be run again.
        const deleteResponse = await this._delete_id(
            request, response.body.data.id);
        if (deleteResponse.error === undefined) {
            response.deleted = "after";
            return response;
        }
        return deleteResponse;

        // return Promise.resolve({error:"Not implemented."});
        // fetch(
        //     [Headless.apis["go-rest"].base, "users"].join('/'),
        //     {method:"POST", body: blob, headers:command.headers}
        // )
        // .then(response => Promise.all([response, response.json()]))
        // .then(([response, body]) => {
        //     console.log(response, body)
        // })
        // .catch(error => {
        //     console.log(error);
        // });



        // console.log('in time out for send.');
        // .then(response => Promise.all([response, response.json()]))
        // .then(([response, body]) => {
        //     // console.log(response, body)
        //     const result = {
        //         ok:response.ok, body:body, status:response.status,
        //         statusText:response.statusText
        //     };
        //     this._transcribe(result);
        //     this._bridge.sendObject(result);
        // })
        // .catch(error => {
        //     // console.log(error);
        //     const result = {error:`${error}`};
        //     this._transcribe(result);
        //     this._bridge.sendObject(result);
        // });

    }

    async _delete_matches(
        request, userDetails, duplicates=undefined, startPage=1
    ) {
        if (duplicates === undefined) {
            duplicates = [];
        }

        // The standard API doesn't seem to facilitate:
        //
        // -   Copying a Request but changing the url.
        // -   Filtering out one key from an object.
        //
        // Code here creates a new request from parts of the supplied request,
        // which will be a POST.
        const pageURI = new URL(request.url);
        pageURI.searchParams.set('page', startPage);
        const getRequest = new Request(pageURI, {
            headers: request.headers, cache: request.cache
        });
        console.log(this._request_JSON(getRequest));
        
        const pageResponse = await this._fetch_JSON(getRequest);
        if (pageResponse.error !== undefined) {
            return pageResponse;
        }
        
        // (this._build_command({
        //     method:"GET", api:'go-rest', path:['users'],
        //     parameters:{page:startPage}
        // }));
        console.log('match page', startPage, pageResponse.body);

        if (startPage > pageResponse.body.meta.pagination.pages) {
            return duplicates;
        }

        let deleteNow = null;
        for(const user of pageResponse.body.data) {
            // console.log(user.email);
            if (user.email === userDetails.email) {
                deleteNow = `${user.id}`;
                break;
            }
        }

        if (deleteNow !== null) {
            console.log('Deleting', startPage, deleteNow);
            const deleteResponse = await this._delete_id(request, deleteNow);
            console.log(deleteResponse);

            // console.log('Deleted', deleteResult)
        // Delete the one to be deleted now, then return delete_matches starting at page 1.


            duplicates.push(deleteNow);
            // startPage = 0;
        }

        return this._delete_matches(
            request, userDetails, duplicates, startPage + 1);
    }

    async _delete_id(request, userIdentifier) {
        const deleteURI = new URL(request.url);
        deleteURI.pathname = [
            ...deleteURI.pathname.split("/"), userIdentifier
        ].join("/");
        const deleteRequest = new Request(deleteURI, {
            headers: request.headers, cache: request.cache, method:"DELETE"
        });
        return await this._fetch_JSON(deleteRequest);
    // return this._fetch_one(this._build_command({
        //     method:"DELETE", api:'go-rest', path:['users', `${userIdentifier}`]
        // }));
    }

    _transcribe(result) {
        const pre = document.createElement('pre');
        pre.append(JSON.stringify(result, undefined, 4));
        this._hr.insertAdjacentElement('afterend', pre);
    }
}
Headless.apis = {
    'star-wars': {
        protocol: "http",
        hostname: "swapi.dev",
        path: ["api"],
        headers: {}
    },
    'go-rest': {
        protocol: "https",
        hostname: "gorest.co.in",
        path: ["public-api"],
        headers: {'Content-Type': 'application/json'}
    }
};

export default function(bridge) {
    new Headless(bridge);
    return null;
}
