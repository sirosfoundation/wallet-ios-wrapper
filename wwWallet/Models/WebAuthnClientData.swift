//
//  WebAuthnClientData.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 09.01.26.
//

import Foundation
import CryptoKit

class WebAuthnClientData: Codable {

    enum `Type`: String, Codable {
        case create = "webauthn.create"
        case get = "webauthn.get"
    }

    // Explicit CodingKeys in the canonical WebAuthn spec order:
    // https://www.w3.org/TR/webauthn/#dictionary-client-data
    enum CodingKeys: String, CodingKey {
        case type
        case challenge
        case origin
        case crossOrigin
    }

    /**
     The operation type the Client Data will be used for. This property has the value `create`
     when creating new credentials and `get when getting an assertion from an existing credential.
     */
    let type: `Type`

    /**
     The challenge received from the WebAuthN Relying Party as web-safe BASE64 encoded string.
     */
    let challenge: String

    /**
     This member contains the fully qualified origin of the requester, as provided to the authenticator by the client.
     */
    let origin: String

    /**
     Indicates whether the credential was used in a cross-origin context. Always `false` for
     direct (same-origin) authentication requests, as required by the WebAuthn spec.
     */
    let crossOrigin: Bool = false

    /**
     This is a derived property which returns the clientDataJson as defined by WebAuthN:
     https://www.w3.org/TR/webauthn/#sec-client-data

     The result is cached so that every access returns the exact same bytes. This is critical
     because `clientDataHash` (sent to the authenticator) and the response construction both
     call this property — they must hash/encode the identical byte sequence.
     */
    var jsonData: Data {
        get throws {
            _jsonDataLock.lock()
            defer { _jsonDataLock.unlock() }

            if let cached = _jsonData {
                return cached
            }
            let data = try JSONEncoder().encode(self)
            _jsonData = data
            return data
        }
    }

    private let _jsonDataLock = NSLock()
    private var _jsonData: Data?

    /**
     This is a derived property which returns the SHA-256 of the `jsonData`.
     */
    var clientDataHash: Data {
        get throws {
            Data(SHA256.hash(data: try jsonData))
        }
    }


    init?(type: `Type`, challenge: String, origin: String) {
        // For an unknown reason, we cannot just pass the string through, but need to reencode,
        // to make sure, e.g. there are no "=" at the end. Otherwise, authentication will fail.
        guard let challenge = challenge.webSafeBase64DecodedData()?.webSafeBase64EncodedString() else {
            return nil
        }

        self.type = type
        self.challenge = challenge
        self.origin = origin
    }
}
