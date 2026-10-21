//
//  Title.swift
//
//  Created by Benjamin Erhart on 21.10.26.
//

import SwiftUI

struct Title: View {

    let text: String
    let alignment: TextAlignment
    let font: Font

    init(_ text: String, alignment: TextAlignment = .center, font: Font = .title)
    {
        self.text = text
        self.alignment = alignment
        self.font = font
    }

    var body: some View {
        Text(text)
            .frame(maxWidth: .infinity, alignment: .from(textAlignment: alignment))
            .multilineTextAlignment(alignment)
            .font(font)
            .padding(.vertical)
    }
}

extension Alignment {

    static func from(textAlignment: TextAlignment) -> Alignment {
        switch textAlignment {
        case .leading:
            return .leading
            
        case .center:
            return .center
            
        case .trailing:
            return .trailing
        }
    }
}

#Preview {
    Title("This Is a Multiline Test Title, but only with this additional text.", alignment: .leading)

    Title("This Is a Multiline Test Title, but only with this additional text.", alignment: .center)

    Title("This Is a Multiline Test Title, but only with this additional text.", alignment: .trailing)
}
