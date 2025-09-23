//
//  wwWalletApp.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI
import IdentityDocumentServices

@main
struct wwWalletApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear() {
                    print("Hello, World!")

                    if #available(iOS 26.0, *) {
                        Task {
                            let store = IdentityDocumentProviderRegistrationStore()

                            let registration = MobileDocumentRegistration(
                                mobileDocumentType: "org.iso.18013.5.1.mDL",
                                supportedAuthorityKeyIdentifiers: [Data([0x01, 0x02, 0x03])],
                                documentIdentifier: "foobar",
                                invalidationDate: Calendar.current.date(byAdding: .init(month: 1), to: .now))

                            do {
                                try await store.addRegistration(registration)
                            }
                            catch {
                                print(error)
                            }
                        }
                    }
                }
        }
    }
}
