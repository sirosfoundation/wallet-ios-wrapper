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

    // MARK: - Helpers

    /// Returns a valid web-safe base64-encoded challenge for use in tests.
    private func makeChallenge(_ text: String = "test_challenge") -> String {
        text.data(using: .utf8)!.webSafeBase64EncodedString()
    }

    // MARK: - Tests

    @Test("Test WebAuthnClientData initialization")
    func testWebAuthnClientDataInit() {
        let challenge = makeChallenge()
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
        let challenge = makeChallenge()
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
        let challenge = makeChallenge()
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
        let challenge = makeChallenge()
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
        let challenge = makeChallenge()
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
        let challenge = makeChallenge("abc123")
        let origin = "https://id.example.com"

        let clientData = WebAuthnClientData(type: .get, challenge: challenge, origin: origin)
        #expect(clientData != nil)

        do {
            let jsonData = try clientData!.jsonData
            let jsonString = String(data: jsonData, encoding: .utf8)!

            // Verify all required keys are present before comparing positions
            #expect(jsonString.range(of: "\"type\"") != nil, "JSON missing 'type' key")
            #expect(jsonString.range(of: "\"challenge\"") != nil, "JSON missing 'challenge' key")
            #expect(jsonString.range(of: "\"origin\"") != nil, "JSON missing 'origin' key")
            #expect(jsonString.range(of: "\"crossOrigin\"") != nil, "JSON missing 'crossOrigin' key")

            guard let typeIdx = jsonString.range(of: "\"type\"")?.lowerBound,
                  let challengeIdx = jsonString.range(of: "\"challenge\"")?.lowerBound,
                  let originIdx = jsonString.range(of: "\"origin\"")?.lowerBound,
                  let crossOriginIdx = jsonString.range(of: "\"crossOrigin\"")?.lowerBound
            else {
                #expect(Bool(false), "One or more expected JSON keys were missing")
                return
            }

            // Verify canonical WebAuthn spec key order: type → challenge → origin → crossOrigin
            #expect(typeIdx < challengeIdx, "Expected 'type' before 'challenge'")
            #expect(challengeIdx < originIdx, "Expected 'challenge' before 'origin'")
            #expect(originIdx < crossOriginIdx, "Expected 'origin' before 'crossOrigin'")
        } catch {
            #expect(Bool(false), "Unexpected error: \(error)")
        }
    }

    @Test("Test JSON contains crossOrigin: false")
    func testJsonContainsCrossOriginFalse() {
        let challenge = makeChallenge("abc123")
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
        let challenge = makeChallenge("abc123")
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
