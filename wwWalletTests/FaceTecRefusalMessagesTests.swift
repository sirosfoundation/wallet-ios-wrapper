//
//  FaceTecRefusalMessagesTests.swift
//  wwWalletTests
//
//  Pins what the user is told when facetec-api refuses to issue a credential,
//  and that every one of those messages is translated.
//

import Testing
import Foundation
@testable import wwWallet

@Suite("FaceTec refusal messages")
struct FaceTecRefusalMessagesTests {

    /// The refusal codes facetec-api v0.16.0 returns in
    /// `credentialIssueErrorCode` on `/process-request`
    /// (internal/idverrors/errors.go), except `session_expired`: only the
    /// legacy `/v1/id-scan` path answers that one. On `/process-request` an
    /// expired or used-up liveness proof is reported as `liveness_failed`.
    static let codes = [
        "liveness_failed",
        "match_failed",
        "document_unreadable",
        "policy_rejected",
        "nfc_skipped",
        "chip_untrusted",
        "nfc_not_requested",
        "nfc_device_not_capable",
        "nfc_chip_read_failed",
        "nfc_not_authenticated",
        "document_expired",
        "issuance_failed",
        "internal_error",
    ]

    private static let translations = ["el", "fi", "pt", "sv"]

    private static func message(for code: String) -> String {
        Errors.faceTecIssuanceRefused(code: code).localizedDescription
    }

    @Test("Each refusal code has its own message", arguments: codes)
    func eachCodeHasItsOwnMessage(code: String) {
        let generic = Self.message(for: "a_code_no_one_has_heard_of")

        #expect(!Self.message(for: code).isEmpty)
        #expect(Self.message(for: code) != generic, "\(code) falls through to the generic message")
    }

    @Test("No two refusal codes share a message")
    func messagesAreDistinct() {
        let messages = Set(Self.codes.map(Self.message(for:)))

        #expect(messages.count == Self.codes.count)
    }

    @Test("An unknown code still gets an actionable message")
    func unknownCodeGetsGenericMessage() {
        #expect(!Self.message(for: "a_code_no_one_has_heard_of").isEmpty)
        #expect(!Self.message(for: "").isEmpty)
    }

    /// The catalog is keyed by the English text, so an edit to a message in
    /// `Errors.swift` without the same edit in the catalog silently drops its
    /// translations. Needs the tests to run with English as the language.
    @Test("Every refusal message is translated in every supported language")
    func messagesAreTranslated() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("wwWallet/Localizable.xcstrings")
        let catalog = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try #require(catalog["strings"] as? [String: [String: Any]])

        let english = Self.codes.map(Self.message(for:))
            + [Errors.faceTecNFCUnavailable.localizedDescription,
               "No credential issued", // title of the alert that shows a refusal
               "OK"]

        for text in english {
            let entry = try #require(strings[text], "not in Localizable.xcstrings: \(text)")
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]

            for language in Self.translations {
                let unit = localizations[language]?["stringUnit"] as? [String: Any]
                let value = unit?["value"] as? String ?? ""

                #expect(unit?["state"] as? String == "translated", "\(language) not translated: \(text)")
                #expect(!value.isEmpty, "\(language) is empty: \(text)")
            }
        }
    }
}
