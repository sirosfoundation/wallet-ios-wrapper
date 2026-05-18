//
//  WebAuthn.User+Extensions.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 13.05.26.
//

import Foundation
import YubiKit

extension WebAuthn.User {
    
    var fallbackName: String {
        displayName ?? name ?? id.base64EncodedString()
    }
}
