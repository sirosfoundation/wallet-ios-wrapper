//
//  PinEntryView.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 20.10.26.
//

import SwiftUI

struct PinEntryView: View {


    @State
    private var pin: String = ""

    var body: some View {
        Text(NSLocalizedString("Enter Your Security Key PIN", comment: ""))

        TextField(NSLocalizedString("PIN", comment: ""), text: $pin)
            .autocorrectionDisabled()
            .textFieldStyle(.roundedBorder)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

        Button {
            // TODO
        } label: {
            Text(NSLocalizedString("Confirm", comment: ""))
        }

        Button {
            // TODO
        } label: {
            Text(NSLocalizedString("Cancel", comment: ""))
        }
    }
}

#Preview {
    PinEntryView()
}
