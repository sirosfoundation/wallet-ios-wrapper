//
//  ExtensionsTests.swift
//  wwWalletTests
//
//  Created by Benjamin Erhart on 15.04.26.
//

import Testing
@testable import wwWallet
internal import YubiKit

@Suite("Extensions Test Suite")
struct ExtensionsTests {

    private let secrets = MockYubiKitHmacSecrets(first: Data([0, 1, 2]), second: Data([3, 4, 5]))


    @Test("Test PrfSecrets")
    func testPrfSecrets() {
        let prfSecrets = PrfSecrets(secrets)

        #expect(prfSecrets?.first?.webSafeBase64DecodedData() == secrets.first)
        #expect(prfSecrets?.second?.webSafeBase64DecodedData() == secrets.second)
    }

    @Test("Test Prf")
    func testPrf() {
        var prf = Prf(nil as YubiKitHmacSecrets?)

        #expect(prf == nil)

        prf = Prf(secrets)

        #expect(prf?.enabled == nil)
        #expect(prf?.results?.first?.webSafeBase64DecodedData() == secrets.first)
        #expect(prf?.results?.second?.webSafeBase64DecodedData() == secrets.second)


        prf = Prf(.enabled)

        #expect(prf?.enabled == true)
        #expect(prf?.results == nil)
    }

    @Test("Test Extensions")
    func testExtensions() {
        var extensions = Extensions(nil as YubiKitHmacSecrets?)

        #expect(extensions == nil)

        extensions = Extensions(secrets)

        #expect(extensions?.prf?.enabled == nil)
        #expect(extensions?.prf?.results?.first?.webSafeBase64DecodedData() == secrets.first)
        #expect(extensions?.prf?.results?.second?.webSafeBase64DecodedData() == secrets.second)

        extensions = Extensions(.enabled)

        #expect(extensions?.prf?.enabled == true)
        #expect(extensions?.prf?.results == nil)
    }

    @Test("Test PrfExtensions getSecrets helper method")
    func testPrfExtensionsGetSecrets() {
        // Test with valid extension data
        let validExtensions: [String: Any] = [
            "prf": [
                "eval": [
                    "first": Data([0, 1, 2]).webSafeBase64EncodedString(),
                    "second": Data([3, 4, 5]).webSafeBase64EncodedString()
                ],
                "evalByCredential": ["foo": [
                    "first": Data([6, 7, 8]).webSafeBase64EncodedString(),
                    "second": Data([9, 10, 11]).webSafeBase64EncodedString()
                ]]
            ]
        ]

        var secrets = PrfExtensions.getSecrets(from: validExtensions)
        #expect(secrets != nil)
        #expect(secrets?.first == Data([0, 1, 2]))
        #expect(secrets?.second == Data([3, 4, 5]))

        secrets = PrfExtensions.getSecrets(from: validExtensions, for: "foo")
        #expect(secrets != nil)
        #expect(secrets?.first == Data([6, 7, 8]))
        #expect(secrets?.second == Data([9, 10, 11]))

        secrets = PrfExtensions.getSecrets(from: validExtensions, for: "bar")
        #expect(secrets == nil)

        // Test with no extensions
        let noExtensionsSecrets = PrfExtensions.getSecrets(from: nil)
        #expect(noExtensionsSecrets == nil)

        // Test with invalid extension data
        let invalidExtensions: [String: Any] = [
            "prf": [
                "someOtherKey": "value"
            ]
        ]

        let invalidSecrets = PrfExtensions.getSecrets(from: invalidExtensions)
        #expect(invalidSecrets == nil)
    }
}

struct MockYubiKitHmacSecrets: YubiKitHmacSecrets {

    let first: Data

    let second: Data?
}
