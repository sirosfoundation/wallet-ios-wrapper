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
            Color.modalBackground
                .ignoresSafeArea()

            ViewThatFits(in: [.vertical]) {
                content()

                ScrollView {
                    content()
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .clipShape(.rect(cornerRadius: 16))
            .shadow(radius: 10)
            .padding()
            .frame(maxWidth: 400)
        }
    }
}

#Preview("Small Content") {
    Modal {
        Text("Hello World!")
    }
}

#Preview("Large Content") {
    Modal {
        VStack(spacing: 20) {
            Text("I am very long content!")
                .font(.title)
            ForEach(0..<25) { i in
                Text("Item line number \(i)")
            }
        }
    }
}
