//
//  Modal.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 22.10.26.
//

import SwiftUI

struct Modal<Content: View>: View {

    let content: () -> Content


    init(content: @escaping () -> Content) {
        self.content = content
    }


    var body: some View {
        ZStack {
            Color(.label).opacity(0.4)
                .ignoresSafeArea()

            content()
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .shadow(radius: 10)
            .padding()
            .frame(maxWidth: 400)
        }
    }
}

#Preview {
    Modal {
        Text("Hello World!")
    }
}
