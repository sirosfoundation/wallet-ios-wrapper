//
//  WebAuthnClientDataTests.swift
//  wwWalletTests
//
//  Created by Benjamin Erhart on 15.04.26.
//

import Testing
import CryptoKit
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
        #expect(clientData?.crossOrigin == false)
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
            #expect(decoded.crossOrigin == false)
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

    @Test("Test jsonData returns identical bytes on repeated calls (caching)")
    func testJsonDataIsCached() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let origin = "https://example.com"

        let clientData = WebAuthnClientData(type: .get, challenge: challenge, origin: origin)
        #expect(clientData != nil)

        do {
            let first = try clientData!.jsonData
            let second = try clientData!.jsonData
            // Both calls must return the same byte sequence so that clientDataHash and
            // the response payload never diverge.
            #expect(first == second)
        } catch {
            #expect(Bool(false), "jsonData threw unexpectedly: \(error)")
        }
    }

    @Test("Test clientDataHash is consistent with jsonData")
    func testClientDataHashConsistency() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")
        let origin = "https://example.com"

        let clientData = WebAuthnClientData(type: .get, challenge: challenge, origin: origin)
        #expect(clientData != nil)

        do {
            let jsonData = try clientData!.jsonData
            let expectedHash = Data(SHA256.hash(data: jsonData))
            let actualHash = try clientData!.clientDataHash
            // The hash must be computed over the exact same bytes that are sent to the server.
            #expect(actualHash == expectedHash)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Test JSON key ordering follows WebAuthn spec (type, challenge, origin, crossOrigin)")
    func testJsonKeyOrdering() {
        let challenge = "abc123".data(using: .utf8)!.webSafeBase64EncodedString()
        let origin = "https://id.example.com"

        let clientData = WebAuthnClientData(type: .get, challenge: challenge, origin: origin)
        #expect(clientData != nil)

        do {
            let jsonData = try clientData!.jsonData
            let jsonString = String(data: jsonData, encoding: .utf8)!

            // Verify canonical WebAuthn spec key order: type → challenge → origin → crossOrigin
            let typeIdx = jsonString.range(of: "\"type\"")!.lowerBound
            let challengeIdx = jsonString.range(of: "\"challenge\"")!.lowerBound
            let originIdx = jsonString.range(of: "\"origin\"")!.lowerBound
            let crossOriginIdx = jsonString.range(of: "\"crossOrigin\"")!.lowerBound

            #expect(typeIdx < challengeIdx)
            #expect(challengeIdx < originIdx)
            #expect(originIdx < crossOriginIdx)
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Test JSON contains crossOrigin: false")
    func testJsonContainsCrossOriginFalse() {
        let challenge = "abc123".data(using: .utf8)!.webSafeBase64EncodedString()
        let origin = "https://id.example.com"

        let clientData = WebAuthnClientData(type: .get, challenge: challenge, origin: origin)
        #expect(clientData != nil)

        do {
            let jsonData = try clientData!.jsonData
            let jsonString = String(data: jsonData, encoding: .utf8)!

            #expect(jsonString.contains("\"crossOrigin\":false"))
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Test JSON origin is not escaped (no backslash before forward slash)")
    func testJsonOriginNotEscaped() {
        let challenge = "abc123".data(using: .utf8)!.webSafeBase64EncodedString()
        let origin = "https://id.example.com"

        let clientData = WebAuthnClientData(type: .get, challenge: challenge, origin: origin)
        #expect(clientData != nil)

        do {
            let jsonData = try clientData!.jsonData
            let jsonString = String(data: jsonData, encoding: .utf8)!

            // Swift's JSONEncoder must NOT escape forward slashes (no `\/`)
            #expect(!jsonString.contains("\\/"))
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }
}
