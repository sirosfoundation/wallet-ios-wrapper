//
//  NativeWrapper.js
//  wwWallet
//
//  Created by Jens Utbult on 2024-12-13.
//

window.nativeWrapper = (function (nativeWrapper) {
    console.log("Initializing nativeWrapper");

    // Wrap a native page handler as a promise-returning method whose result is
    // decoded from base64 JSON.
    function createWrappedMethod(funcName) {
        nativeWrapper[funcName] = function (arg) {
            console.log("NativeWrapper, ", funcName, arg);

            return window.webkit.messageHandlers['__' + funcName + '__']
            .postMessage(stringify(arg === undefined ? null : arg))
            .then(function (msg) {
                var reply = __b64ToJson(msg);
                console.log(funcName, "result:", reply);

                return reply;
              })
              .catch(
                  function (err) {
                      console.log("error: ", err);
                      throw err;
                  }
              );
        };
    }

    // ISO 18013-5 proximity is now a session hosted by the SDK, not eight GATT
    // methods. The page starts one and gets an engagement URI for its QR code;
    // the session then runs natively and asks the page for the three things
    // the page still owns.
    createWrappedMethod('proximityStart');
    createWrappedMethod('proximityStop');

    // Fire-and-forget, matching the `startScanPhysicalId?(): void` contract in
    // wallet-frontend's NativeWrapperProvider.tsx (no Promise/return value expected,
    // unlike the proximity methods above). Mirrors Android's
    // WalletJsBridge.startScanPhysicalId -> PhotoIdMatchActivity kickoff.
    nativeWrapper['startScanPhysicalId'] = function () {
        console.log("NativeWrapper, startScanPhysicalId");

        window.webkit.messageHandlers.__startScanPhysicalId__.postMessage("")
        .catch(function (err) {
            console.log("startScanPhysicalId error: ", err);
        });
    };

    // -----------------------------------------------------------------------
    // Native to webview call channels.
    //
    // A native session asks the page for the pieces it still owns. Each feature
    // gets its own channel - its own handler registry and the entry points
    // native drives it through - built by __makeCallNamespace__ so no feature
    // shares another's handlers, and adding the next one is two lines rather
    // than a copy of this machinery. Payloads are UTF-8 JSON in base64 in both
    // directions, so quoting, newlines and U+2028/U+2029 stop being hazards and
    // a binary payload needs no separate encoding.
    //
    // onProximityRequest is the same contract the Android wrapper exposes, so
    // one page implementation serves both. The channels here are thinner than
    // Android's: WebKit's callAsyncJavaScript awaits a returned promise, so
    // there is no call id, no reply channel back across the bridge, and nothing
    // to cancel.
    // -----------------------------------------------------------------------

    function __b64ToJson(b64) {
        if (!b64) return null;

        var binary = atob(b64);
        var bytes = new Uint8Array(binary.length);
        for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);

        return JSON.parse(new TextDecoder().decode(bytes));
    }

    function __jsonToB64(value) {
        var bytes = new TextEncoder().encode(JSON.stringify(value === undefined ? null : value));
        var binary = '';
        for (var i = 0; i < bytes.length; i++) binary += String.fromCharCode(bytes[i]);

        return btoa(binary);
    }

    // One feature's channel. `label` only shapes error and log text; the
    // registry is private to the returned object.
    function __makeCallNamespace__(label) {
        return {
            handlers: {},

            // Request/response: run the named handler and return its base64 JSON.
            invoke: async function (name, payloadB64) {
                var handler = this.handlers[name];

                if (typeof handler !== 'function') {
                    throw new Error('no_handler: no ' + label + ' handler registered for ' + name);
                }

                var payload;
                try {
                    payload = __b64ToJson(payloadB64);
                }
                catch (e) {
                    throw new Error('bad_payload: ' + String(e));
                }

                return __jsonToB64(await handler(payload));
            },

            // One-way: progress and terminal events. Errors in a listener are swallowed.
            notify: function (name, payloadB64) {
                var handler = this.handlers[name];

                if (typeof handler !== 'function') return;

                try {
                    handler(__b64ToJson(payloadB64));
                }
                catch (e) {
                    console.log(label + ' notify handler for ' + name + ' threw: ' + e);
                }
            },
        };
    }

    // Register a handler on `namespace` by short name. Returns an unregister
    // function that removes only this handler, not whatever later replaced it:
    // a later registration for the same name wins, and a stale unregister from
    // the handler it replaced must not silently unhook the live one.
    function __registerCallHandler__(namespace, name, handler) {
        namespace.handlers[name] = handler;

        return function () {
            if (namespace.handlers[name] === handler) {
                delete namespace.handlers[name];
            }
        };
    }

    // Proximity: an ISO 18013-5 session hosted natively that asks the page for
    // its credentials, the user's consent, and a signature.
    nativeWrapper.__proximity__ = __makeCallNamespace__('proximity');

    /** Register a proximity handler by short name. Returns an unregister function. */
    nativeWrapper.onProximityRequest = function (name, handler) {
        return __registerCallHandler__(nativeWrapper.__proximity__, name, handler);
    };

    console.log("nativeWrapper initialized");

    return nativeWrapper;
})({});
