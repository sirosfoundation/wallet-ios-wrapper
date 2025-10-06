//
//  RequestAuthorizationView.swift
//  IdentityProviderExtension
//
//  Created by Benjamin Erhart on 06.10.25.
//

import SwiftUI
import IdentityDocumentServices
import IdentityDocumentServicesUI

struct RequestAuthorizationView: View {

    let context: ISO18013MobileDocumentRequestContext

    var body: some View {
        VStack {
            RequestInfoView(request: context.request)

            Button(NSLocalizedString("Accept", comment: "")) {
                acceptVerification()
            }

            Button(NSLocalizedString("Decline", comment: "")) {
                context.cancel()
            }
        }
    }

    private func acceptVerification() {
        Task {
            try await context.sendResponse { rawRequest in
                try await validateConsistency(context.request, rawRequest)

                try await validateRawRequest(rawRequest)

                let response = try await buildAndEncryptResponse(rawRequest)

                return .init(responseData: response)
            }
        }
    }

    private func validateConsistency(_ request: ISO18013MobileDocumentRequest, _ rawRequest: IdentityDocumentWebPresentmentRawRequest) async throws {
        // TODO
    }

    private func validateRawRequest(_ rawRequest: IdentityDocumentWebPresentmentRawRequest) async throws {
        // TODO
    }

    private func buildAndEncryptResponse(_ rawRequest: IdentityDocumentWebPresentmentRawRequest) async throws -> Data {
        // TODO

        return .init()
    }
}
