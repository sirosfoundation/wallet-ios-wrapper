//
//  WiredConnectionManager.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 20.10.26.
//

import Foundation
import YubiKit

/**
 * On iOS we cannot ask for wired and NFC connections at the same time, where the first one wins,
 * as we can on Android.
 *
 * Instead, we have this `WiredConnectionManager` here, which shall be initialized on app start,
 * and which will then scan for a Lightning or USB-C connection in the background continuously.
 *
 * When we then receive get or create requests, we check, if a wired connection is available,
 * and if not, initiate an NFC connection instead.
 *
 * Not optimal, as the user will have no chance of using a wired connection after that. They will
 * have to cancel the NFC request and start over instead. But probably better than having the
 * user choose in the UI instead.
 */
final class WiredConnectionManager {

    static let shared = WiredConnectionManager()


    private(set) var wiredConnection: SmartCardConnection?

    private(set) var error: Error?


    private var wiredConnectionTask: Task<Void, Never>?


    private init() {
        startWiredConnection()
    }


    private func startWiredConnection() {
        wiredConnectionTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    error = nil

                    guard !Task.isCancelled else {
                        return
                    }

                    let newConnection = try await WiredSmartCardConnection.makeConnection()

                    guard !Task.isCancelled else {
                        return
                    }

                    wiredConnection = newConnection

                    let closeError = await newConnection.waitUntilClosed()

                    wiredConnection = nil

                    if let closeError {
                        error = closeError
                    }
                }
                catch {
                    self.error = error
                }
            }
        }
    }
}
