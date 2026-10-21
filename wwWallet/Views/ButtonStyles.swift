//
//  ButtonStyles.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-12-18.
//

import SwiftUI

public struct WwWalletButtonStyle: ButtonStyle {

    enum Variant {
        case basic
        case primary
        case outline

        var foregroundColor: Color {
            switch self {
            case .basic, .primary:
                Color.white

            case .outline:
                Color(hex: "0c0e11")!
            }
        }

        var backgroundColor: Color {
            switch self {
            case .basic:
                Color(red: 0, green: 52 / 255, blue: 118 / 255)

            case .primary:
                Color(hex: "1c4587")!

            case .outline:
                Color(hex: "f8f9f9")!
            }
        }

        var borderColor: Color? {
            switch self {
            case .basic, .primary:
                nil

            case .outline:
                Color(hex: "6e7582")!
            }
        }
    }

    let variant: Variant

    init(_ variant: Variant = .primary) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        DisabledEffectView {
            if variant == .basic {
                configuration.label
                    .padding(8)
                    .foregroundStyle(configuration.isPressed ? variant.foregroundColor.opacity(0.5) : variant.foregroundColor)
                    .clipShape(.rect(cornerRadius: 8))
            }
            else {
                let view = configuration.label
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(variant.backgroundColor)
                    .foregroundStyle(configuration.isPressed ? variant.foregroundColor.opacity(0.5) : variant.foregroundColor)
                    .clipShape(.rect(cornerRadius: 8))

                if let borderColor = variant.borderColor {
                    view.overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(borderColor, lineWidth: 1)
                    }
                }
                else {
                    view
                }
            }
        }
    }
}

public extension ButtonStyle where Self == WwWalletButtonStyle {

    static var basicButton: Self {
        .init(.basic)
    }

    static var primaryButton: Self {
        .init(.primary)
    }

    static var outlineButton: Self {
        .init(.outline)
    }
}

struct DisabledEffectView<Content: View>: View {

    @Environment(\.isEnabled)
    private var isEnabled

    let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .grayscale(isEnabled ? 0 : 1) // Greyscale if NOT enabled
    }
}
