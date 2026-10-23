//
//  KeyTouchInfoView.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 22.10.26.
//

import SwiftUI

struct KeyTouchInfoView: View {

    var body: some View {
        Modal {
            VStack {
                Title(NSLocalizedString("Touch Your Security Key", comment: ""))

                Text(NSLocalizedString("Touch the key where it is blinking to confirm you are present.", comment: ""))
                    .font(.callout)
                    .frame(alignment: .center)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                // TODO: Waiting on icon to show here.

            }
        }
    }
}

#Preview {
    KeyTouchInfoView()
}
