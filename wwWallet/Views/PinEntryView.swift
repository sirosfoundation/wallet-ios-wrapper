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


    init(_ onFinished: @escaping (String?) -> Void) {
        self.onFinished = onFinished
    }


    var body: some View {
        Modal {
            VStack {
                Title(NSLocalizedString("Enter Your Security Key PIN", comment: ""))

                SecureField(NSLocalizedString("PIN", comment: ""), text: $pin)
                    .focused($pinFieldFocused)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)
                    .padding(.vertical, 8)
                    .onSubmit {
                        confirm()
                    }

                Button(NSLocalizedString("Confirm", comment: "")) {
                    confirm()
                }
                .disabled(pin.isEmpty)
                .padding(.top, 32)
                .padding(.vertical, 8)
                .buttonStyle(.primaryButton)

                Button(NSLocalizedString("Cancel", comment: "")) {
                    onFinished(nil)

                    dismiss()
                }
                .padding(.vertical, 8)
                .buttonStyle(.outlineButton)
            }
        }
        .onAppear {
            pinFieldFocused = true
        }
    }


    private func confirm() {
        if !pin.isEmpty {
            onFinished(pin)

            dismiss()
        }
    }
}

#Preview {
    PinEntryView { pin in
        print("PIN: \(pin ?? "(nil)")")
    }
}
