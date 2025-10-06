//
//  DocumentProviderExtension.swift
//  IdentityProviderExtension
//
//  Created by Benjamin Erhart on 19.09.25.
//

import ExtensionKit
import IdentityDocumentServicesUI
import IdentityDocumentServices
import SwiftUI

@main
struct DocumentProviderExtension: IdentityDocumentProvider {

    private let store = IdentityDocumentProviderRegistrationStore()

    var body: some IdentityDocumentRequestScene {
        ISO18013MobileDocumentRequestScene { context in
            RequestAuthorizationView(context: context)
        }
    }

    func performRegistrationUpdates() async {
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
