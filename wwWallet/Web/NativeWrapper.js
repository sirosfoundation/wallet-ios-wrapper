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
    // Calls FROM native INTO the page.
    //
    // The page registers handlers; native invokes them by name and awaits the
    // promise. Payloads are UTF-8 JSON in base64 in both directions, so
    // quoting, newlines and U+2028/U+2029 stop being hazards and a binary
    // payload needs no separate encoding.
    //
    // `onRequest` is the same contract the Android wrapper exposes, so one
    // page implementation serves both. `__invoke__` and `__notify__` are not:
    // WebKit's callAsyncJavaScript awaits a returned promise, so unlike
    // Android there is no call id, no reply channel back across the bridge,
    // and nothing to cancel.
    // -----------------------------------------------------------------------

    nativeWrapper.__handlers__ = {};

    /** Register a handler native can invoke. Returns an unregister function. */
    nativeWrapper.onRequest = function (name, handler) {
        nativeWrapper.__handlers__[name] = handler;

        // Only remove this handler, not whatever replaced it: a later
        // onRequest for the same name wins, and a stale unregister from the
        // handler it replaced must not silently unhook the live one.
        return function () {
            if (nativeWrapper.__handlers__[name] === handler) {
                delete nativeWrapper.__handlers__[name];
            }
        };
    };

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

    nativeWrapper.__invoke__ = async function (name, payloadB64) {
        var handler = nativeWrapper.__handlers__[name];

        if (typeof handler !== 'function') {
            throw new Error('no_handler: no handler registered for ' + name);
        }

        var payload;
        try {
            payload = __b64ToJson(payloadB64);
        }
        catch (e) {
            throw new Error('bad_payload: ' + String(e));
        }

        return __jsonToB64(await handler(payload));
    };

    /** One-way: progress and terminal events. Errors in a listener are swallowed. */
    nativeWrapper.__notify__ = function (name, payloadB64) {
        var handler = nativeWrapper.__handlers__[name];

        if (typeof handler !== 'function') return;

        try {
            handler(__b64ToJson(payloadB64));
        }
        catch (e) {
            console.log('notify handler for ' + name + ' threw: ' + e);
        }
    };

    console.log("nativeWrapper initialized");

    return nativeWrapper;
})({});
