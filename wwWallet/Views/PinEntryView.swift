//
//  PinEntryView.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 20.10.26.
//

import SwiftUI

struct PinEntryView: View {

    var onFinished: (String?) -> Void

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var pin: String = ""

    @FocusState
    private var pinFieldFocused: Bool

    var body: some View {
        ZStack {
            Color(.label).opacity(0.4)
                .ignoresSafeArea()

            VStack {
                Title(NSLocalizedString("Enter Your Security Key PIN", comment: ""))

                SecureField(NSLocalizedString("PIN", comment: ""), text: $pin)
                    .focused($pinFieldFocused)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)

                Button {
                    onFinished(pin)

                    dismiss()
                } label: {
                    Text(NSLocalizedString("Confirm", comment: ""))
                }
                .disabled(pin.isEmpty)
                .padding(.top, 32)
                .padding(.vertical, 8)
                .buttonStyle(.primaryButton)

                Button {
                    onFinished(nil)

                    dismiss()
                } label: {
                    Text(NSLocalizedString("Cancel", comment: ""))
                }
                .padding(.vertical, 8)
                .buttonStyle(.outlineButton)
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding()
            .frame(maxWidth: 400)
        }
        .onAppear {
            pinFieldFocused = true
        }
    }
}

#Preview {
    PinEntryView(onFinished: { pin in
        print("PIN: \(pin ?? "(nil)")")
    })
}
