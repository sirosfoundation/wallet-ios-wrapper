//
//  ErrorView.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 05.11.26.
//

import SwiftUI

struct ErrorView : View {

    var message: String

    var onFinished: () -> Void


    @Environment(\.dismiss)
    private var dismiss


    init(_ message: String, _ onFinished: @escaping () -> Void) {
        self.message = message
        self.onFinished = onFinished
    }


    var body: some View {
        Modal {
            VStack {
                Title(NSLocalizedString("There Has Been an Error", comment: ""))

                Text(message)
                    .font(.callout)
                    .frame(alignment: .center)
                    .multilineTextAlignment(.center)

                Image(systemName: "xmark.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(Color.red)
                    .padding()

                Button(NSLocalizedString("Cancel", comment: "")) {
                    onFinished()

                    dismiss()
                }
                .padding(.vertical, 8)
                .buttonStyle(.outlineButton)
            }
        }
    }
}

#Preview {
    ErrorView("Hold the security key against your device's NFC reader until it is recognized.") {
    }
}
