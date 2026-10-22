//
//  wwWalletApp.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI

@main
struct wwWalletApp: App {

    init() {
        // Start to listen for USB-C/Lightning connections right away, so we have it, when we need it.
        _ = WiredConnectionManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
