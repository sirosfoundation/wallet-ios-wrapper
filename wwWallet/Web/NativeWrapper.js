//
//  NativeWrapper.js
//  wwWallet
//
//  Created by Jens Utbult on 2024-12-13.
//

window.nativeWrapper = (function (nativeWrapper) {
    console.log("Initializing nativeWrapper");

    function createBluetoothMethod(funcName) {
        nativeWrapper[funcName] = function (arg) {
            console.log("NativeWrapper, ", funcName, arg);

            return window.webkit.messageHandlers['__' + funcName + '__']
            .postMessage(stringify(arg))
            .then(function (msg) {
                console.log(funcName, "raw result:", msg);

                var reply = JSON.parse(msg);
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

    createBluetoothMethod('bluetoothStatus');
    createBluetoothMethod('bluetoothTerminate');
    createBluetoothMethod('bluetoothCreateServer');
    createBluetoothMethod('bluetoothCreateClient');
    createBluetoothMethod('bluetoothSendToServer');
    createBluetoothMethod('bluetoothSendToClient');
    createBluetoothMethod('bluetoothReceiveFromClient');
    createBluetoothMethod('bluetoothReceiveFromServer');

    // Fire-and-forget, matching the `startScanPhysicalId?(): void` contract in
    // wallet-frontend's NativeWrapperProvider.tsx (no Promise/return value expected,
    // unlike the bluetooth methods above). Mirrors Android's
    // WalletJsBridge.startScanPhysicalId -> PhotoIdMatchActivity kickoff.
    nativeWrapper['startScanPhysicalId'] = function () {
        console.log("NativeWrapper, startScanPhysicalId");

        window.webkit.messageHandlers.__startScanPhysicalId__.postMessage("")
        .catch(function (err) {
            console.log("startScanPhysicalId error: ", err);
        });
    };

    console.log("nativeWrapper initialized");

    return nativeWrapper;
})({});
