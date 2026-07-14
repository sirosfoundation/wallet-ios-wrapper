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

/**
 Struct to keep the result of JSON-encoding `WebAuthnClientData` around.

 It needs to be created once before hashing it, so we can send it back as-is to the server.

 Otherwise re-encoding `WebAuthnClientData` would lead to intermittent bugs, where the signature
 doesn't match the re-encoded `ClientDataJson`, as re-encoding might jumble JSON object key ordering hence
 changing the value of encoded data, which was formerly hashed.

 https://www.w3.org/TR/webauthn/#sec-client-data
 */
struct WebAuthnClientDataJson {

    let json: Data

    /**
     The SHA-256 hash of `json`.
     */
    var hash: Data {
        Data(SHA256.hash(data: json))
    }

    /**
     The web-safe BASE64-encoded `json`.
     */
    var string: String {
        json.webSafeBase64EncodedString()
    }


    init(_ clientData: WebAuthnClientData) throws {
        json = try JSONEncoder().encode(clientData)
    }
}
