//
//  ModalViewController.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 21.10.26.
//

import SwiftUI

class ModalViewController<Content: View>: UIHostingController<Content> {

    override init(rootView: Content) {
        super.init(rootView: rootView)

        Self.applyStyle(vc: self)
    }
    
    @MainActor @preconcurrency
    required dynamic init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)

        Self.applyStyle(vc: self)
    }

    override init?(coder aDecoder: NSCoder, rootView: Content) {
        super.init(coder: aDecoder, rootView: rootView)

        Self.applyStyle(vc: self)
    }


    private static func applyStyle(vc: ModalViewController) {
        vc.modalPresentationStyle = .overFullScreen
        vc.modalTransitionStyle = .crossDissolve
        vc.view.backgroundColor = .clear
    }
}
