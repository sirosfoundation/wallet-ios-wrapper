//
//  RequestInfoView.swift
//  IdentityProviderExtension
//
//  Created by Benjamin Erhart on 06.10.25.
//

import SwiftUI
import IdentityDocumentServices

struct RequestInfoView: View {

    let request: ISO18013MobileDocumentRequest

    
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
    }
}

#Preview {
    RequestInfoView(request: .init(presentmentRequests: [], requestAuthentications: []))
}
