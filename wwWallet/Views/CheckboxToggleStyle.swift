//
//  CheckboxToggleStyle.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 16.11.26.
//

import SwiftUI

struct CheckboxToggleStyle: ToggleStyle {

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.system(size: 32))
                    .foregroundStyle(Color.accent)

                configuration.label
            }
        }
        .buttonStyle(.plain)
        .accessibilityRepresentation {
            Toggle(isOn: .constant(configuration.isOn)) {
                configuration.label
            }
        }
    }
}
