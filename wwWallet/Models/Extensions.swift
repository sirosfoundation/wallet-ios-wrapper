//
//  Extensions.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 15.04.26.
//

import Foundation
import YubiKit

struct Extensions: Codable {

    let prf: Prf?

    init?(_ secrets: YubiKitHmacSecrets?) {
        guard let secrets else {
            return nil
        }

        prf = Prf(secrets)
    }

    init?(_ result: WebAuthn.Extension.PRF.MakeCredentialOperations.Result?) {
        guard let result else {
            return nil
        }

        prf = Prf(result)
    }
}

struct Prf: Codable {

    let results: PrfSecrets?
    let enabled: Bool?

    init?(_ secrets: YubiKitHmacSecrets?) {
        guard let secrets else {
            return nil
        }

        results = PrfSecrets(secrets)
        enabled = nil
    }

    init?(_ result: WebAuthn.Extension.PRF.MakeCredentialOperations.Result?) {
        guard let result else {
            return nil
        }

        switch result {
        case .enabled:
            results = nil
            enabled = true

        case .secrets(let secrets):
            results = PrfSecrets(secrets)
            enabled = nil
        }
    }
}

struct PrfSecrets: Codable {

    let first: String?
    let second: String?

    init?(_ secrets: YubiKitHmacSecrets?) {
        guard let secrets else {
            return nil
        }

        first = secrets.first.webSafeBase64EncodedString()
        second = secrets.second?.webSafeBase64EncodedString()
    }
}

/**
 Use protocol indirection to allow for testing.

 `CTAP2.Extension.HmacSecret.Secrets.init()` is internal and cannot be called in tests.
 */
protocol YubiKitHmacSecrets {

    /// First derived secret (32 bytes).
    var first: Data { get }

    /// Second derived secret (32 bytes), if salt2 was provided.
    var second: Data? { get }
}

extension CTAP2.Extension.HmacSecret.Secrets: YubiKitHmacSecrets {}
