//
//  SetPinView.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 22.10.26.
//

import SwiftUI

struct SetPinView: View {

    var onFinished: (String?) -> Void

    private enum Field {
        case pin1
        case pin2
    }


    @Environment(\.dismiss)
    private var dismiss

    @State
    private var accepted = false

    @State
    private var showStep1 = true

    @State
    private var pin1: String = ""

    @State
    private var pin2: String = ""

    @FocusState
    private var fieldFocused: Field?


    init(_ onFinished: @escaping (String?) -> Void) {
        self.onFinished = onFinished
    }


    var body: some View {
        Modal {
            ZStack {
                if showStep1 {
                    step1
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
                else {
                    step2
                        .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
                }
            }
            .animation(.easeInOut, value: showStep1)
        }
    }

    private var step1: some View {
        VStack {
            Title(NSLocalizedString("No PIN Set", comment: ""))

            Text(NSLocalizedString("Please create a PIN for your security key to protect the Passkeys stored there.", comment: ""))
                .font(.callout)
                .frame(alignment: .center)
                .multilineTextAlignment(.center)
                .padding(.bottom, 16)

            HStack {
                VStack {
                    Text(NSLocalizedString("Please remember your PIN", comment: ""))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.headline)

                    Text(NSLocalizedString("You need a unique PIN to unlock this security key.", comment: ""))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.callout)
                        .padding(.bottom, 8)

                    Text(NSLocalizedString("• Separate from your wallet", comment: ""))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.callout)

                    Text(NSLocalizedString("• Known only to you", comment: ""))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.callout)

                    Text(NSLocalizedString("• Cannot be reset if forgotten", comment: ""))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .font(.callout)
                }

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.accent)
           }
            .padding()
            .background(Color(uiColor: .tertiarySystemBackground))
            .cornerRadius(8)

            Toggle(isOn: $accepted) {
                Text(NSLocalizedString("I understand that I must remember this PIN, as it cannot be recovered.", comment: ""))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .toggleStyle(CheckboxToggleStyle())
            .padding(.top, 8)

            Button(NSLocalizedString("Create PIN", comment: "")) {
                withAnimation {
                    showStep1 = false
                }
            }
            .disabled(!accepted)
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

    private var step2: some View {
        VStack {
            Title(NSLocalizedString("Create Your Security Key PIN", comment: ""))

            SecureField(NSLocalizedString("PIN", comment: ""), text: $pin1)
                .focused($fieldFocused, equals: .pin1)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .textFieldStyle(.roundedBorder)
                .padding(.vertical, 8)
                .onSubmit {
                    fieldFocused = .pin2
                }

            SecureField(NSLocalizedString("Confirm PIN", comment: ""), text: $pin2)
                .focused($fieldFocused, equals: .pin2)
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
            .disabled(pin1.isEmpty || pin1 != pin2)
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
        .onAppear {
            fieldFocused = .pin1
        }
    }

    private func confirm() {
        if !pin1.isEmpty && pin1 == pin2 {
            onFinished(pin1)

            dismiss()
        }
    }
}

#Preview {
    SetPinView({ _ in })
}
