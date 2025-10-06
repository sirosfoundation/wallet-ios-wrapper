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

/**
 Only works with Andoird using OpneID4VP:
  https://digital-credentials.dev
 https://www.corbado.com/blog/how-to-build-verifiable-credential-issuer

 https://developer.mozilla.org/en-US/docs/Web/API/CredentialsContainer/get

 https://developer.apple.com/videos/play/wwdc2025/232/
 https://developer.apple.com/documentation/IdentityDocumentServices/Implenting-as-an-identity-document-provider
 https://developer.apple.com/wallet/get-started-with-verify-with-wallet/

 HPKE: https://datatracker.ietf.org/doc/rfc9180/
 ISO 18013-7:
 - https://www.iso.org/obp/ui#iso:std:iso-iec:ts:18013:-7:ed-2:v1:en
 - https://cdn.standards.iteh.ai/samples/91154/49f64e2fad774d6d8da6c1b326c207e6/ISO-IEC-DTS-18013-7.pdf?utm_source=chatgpt.com

 https://oneiam.medium.com/understanding-iso-18013-5-and-iso-18013-7-the-standards-shaping-mobile-drivers-licenses-mdls-88a4287ac367

 */
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
