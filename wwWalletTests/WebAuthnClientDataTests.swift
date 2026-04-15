//
//  WebAuthnClientDataTests.swift
//  wwWalletTests
//
//  Created by Benjamin Erhart on 15.04.26.
//

import Testing
@testable import wwWallet
internal import YubiKit

@Suite("WebAuthnClientData Test Suite")
struct WebAuthnClientDataTests {

    @Test("Test WebAuthnClientData initialization")
    func testWebAuthnClientDataInit() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let origin = "https://example.com"

        // Test successful initialization
        let clientData = WebAuthnClientData(type: .create, challenge: challenge, origin: origin)
        #expect(clientData != nil)
        #expect(clientData?.type == .create)
        #expect(clientData?.challenge == challenge)
        #expect(clientData?.origin == origin)
    }

    @Test("Test WebAuthnClientData jsonData property")
    func testWebAuthnClientDataJsonData() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let origin = "https://example.com"

        let clientData = WebAuthnClientData(type: .create, challenge: challenge, origin: origin)
        #expect(clientData != nil)

        do {
            let jsonData = try clientData!.jsonData
            #expect(!jsonData.isEmpty)

            // Verify it's valid JSON by attempting to decode it back
            let decoded = try JSONDecoder().decode(WebAuthnClientData.self, from: jsonData)
            #expect(decoded.type == .create)
            #expect(decoded.challenge == challenge)
            #expect(decoded.origin == origin)
        } catch {
            #expect(Bool(false), "Failed to encode/decode jsonData: \(error)")
        }
    }

    @Test("Test WebAuthnClientData clientDataHash property")
    func testWebAuthnClientDataClientDataHash() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString()
        let origin = "https://example.com"

        let clientData = WebAuthnClientData(type: .get, challenge: challenge, origin: origin)
        #expect(clientData != nil)

        do {
            let hash = try clientData!.clientDataHash
            #expect(!hash.isEmpty)

            // SHA-256 hash should be 32 bytes long
            #expect(hash.count == 32)
        } catch {
            #expect(Bool(false), "Failed to encode/decode jsonData: \(error)")
        }
    }
}
