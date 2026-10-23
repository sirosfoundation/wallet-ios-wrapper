//
//  CredentialSelectionView.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 22.10.26.
//

import SwiftUI
import YubiKit

struct CredentialSelectionView: View {

    let onFinished: (WebAuthn.CredentialDescriptor?) -> Void

    private let responses: [InternalResponse]

    @Environment(\.dismiss)
    private var dismiss


    init(_ responses: [CTAP2.GetAssertion.Response], _ onFinished: @escaping (WebAuthn.CredentialDescriptor?) -> Void)
    {
        self.onFinished = onFinished

        self.responses = responses.map { .init($0.user?.fallbackName ?? "", $0.credential)
        }
    }

    fileprivate init(_ responses: [InternalResponse]) {
        onFinished = { _ in }
        self.responses = responses
    }


    var body: some View {
        Modal {
            VStack {
                Title(NSLocalizedString("Select Passkey to Use", comment: ""))

                Text(NSLocalizedString("The security key can have several passkeys on it. Please choose which passkey you would like to log in with.", comment: ""))
                    .font(.callout)
                    .frame(alignment: .center)
                    .multilineTextAlignment(.center)

                List {
                    ForEach(responses) { response in
                        VStack {
                            Text(response.name)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowBackground(Color(.tertiarySystemBackground))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onFinished(response.credential)

                            dismiss()
                        }
                    }
                }
                .frame(maxHeight: 300)
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.vertical, 16)

                Button(NSLocalizedString("Cancel", comment: "")) {
                    onFinished(nil)

                    dismiss()
                }
                .padding(.vertical, 8)
                .buttonStyle(.outlineButton)
            }
        }
    }
}

fileprivate struct InternalResponse: Identifiable {

    let id = UUID()

    let name: String
    let credential: WebAuthn.CredentialDescriptor?

    init(_ name: String, _ credential: WebAuthn.CredentialDescriptor? = nil) {
        self.name = name
        self.credential = credential
    }
}

#Preview {
    CredentialSelectionView([
        .init("foo"), .init("bar"), .init("baz"),
        .init("foo"), .init("bar"), .init("baz"),
        .init("foo"), .init("bar"), .init("baz"),
    ])
}
