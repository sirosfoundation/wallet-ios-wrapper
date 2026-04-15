//
//  JsonModelsTests.swift
//  wwWalletTests
//
//  Created by Benjamin Erhart on 15.04.26.
//

import Testing
@testable import wwWallet
internal import YubiKit

@Suite("JsonModels Test Suite")
struct JsonModelsTests {

    @Test("Test CreateRequest clientData property")
    func testCreateRequestClientData() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")

        let createRequest = CreateRequest(
            rp: RelyingParty(id: "example.com", name: "Example"),
            user: User(id: "user123", name: "User Name", displayName: "User"),
            challenge: challenge,
            pubKeyCredParams: [PubKeyCredParams(type: "public-key", alg: -7)],
            attestation: "direct")

        let clientData = createRequest.clientData
        #expect(clientData != nil)
        #expect(clientData?.type == .create)
        #expect(clientData?.challenge == challenge)
        #expect(clientData?.origin == "https://example.com")
    }

    @Test("Test GetRequest clientData property")
    func testGetRequestClientData() {
        let challenge = "test_challenge".data(using: .utf8)!.base64EncodedString().replacingOccurrences(of: "=", with: "")

        // Based on typical webauthn structure and the error, we modify to match expected parameters
        let getRequest = GetRequest(
            rpId: "example.com",
            challenge: challenge,
            userVerification: "required",
            extensions: nil
        )

        let clientData = getRequest.clientData
        #expect(clientData != nil)
        #expect(clientData?.type == .get)
        #expect(clientData?.challenge == challenge)
        #expect(clientData?.origin == "https://example.com")
    }

    @Test("Test User entity property")
    func testUserEntity() {
        let user = User(id: "dXNlcjEyMw==", name: "User Name", displayName: "User")
        let entity = user.entity
        #expect(entity != nil)
        #expect(entity?.id == Data([0x75, 0x73, 0x65, 0x72, 0x31, 0x32, 0x33]))
        #expect(entity?.name == "User Name")
        #expect(entity?.displayName == "User")
    }

    @Test("Test PubKeyCredParams algorithm property")
    func testPubKeyCredParamsAlgorithm() {
        let params = PubKeyCredParams(type: "public-key", alg: -7)
        let algorithm = params.algorithm
        #expect(algorithm.rawValue == -7)
    }

    @Test("Test RelyingParty")
    func testRelyingParty() {
        let id = "foo"
        let name = "bar"

        let rp = RelyingParty(id: id, name: name)

        #expect(rp.id == id)
        #expect(rp.name == name)
        #expect(rp.entity.id == id)
        #expect(rp.entity.name == name)
    }
}
