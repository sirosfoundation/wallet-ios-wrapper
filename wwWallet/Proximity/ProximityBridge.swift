//
//  ProximityBridge.swift
//  wwWallet
//

import Foundation
import OSLog
import SirosCredentials
import SirosKeystore

/**
 ISO 18013-5 proximity presentation, hosted natively.

 The wrapper used to expose GATT as eight bridge methods and let the page run
 the protocol over them. This replaces that with a session: the page starts
 one and gets an engagement URI back for its QR code, the SDK runs device
 engagement, the BLE role, session establishment, reader authentication and
 device-response assembly, and it calls back into the page for the three
 things the page still owns.

 Everything protocol-shaped here comes from the SDK. This class is wiring: it
 turns seven injected closures into bridge calls and back. It is the Swift
 twin of the Android wrapper's `ProximityBridge.kt`, and the JSON it exchanges
 with the page is identical, so one page implementation serves both.

 Two differences from Android, both forced by the platform:

 - There is no NFC static handover. Android registers the SDK's
   `MdocHostApduService` and publishes a handover-select record; third-party
   iOS apps cannot emulate an NFC Type 4 Tag at all, so engagement here is
   QR only. The SDK knows this: `MdocProximitySession` deliberately does not
   try the NFC session-transcript variant on iOS.
 - The session runs against CoreBluetooth, which needs
   `NSBluetoothAlwaysUsageDescription` in Info.plist. Without it the first
   `CBPeripheralManager` the SDK creates terminates the app.
 */
final class ProximityBridge {

    /// Which BLE role the wallet plays. The engagement always offers both;
    /// this picks the one to actually start.
    enum Mode: String {

        /// mdoc peripheral server: the wallet is the GATT server and advertises.
        case peripheral

        /// mdoc central client: the wallet is the GATT client and scans for the reader.
        case central
    }

    /// Handler names the page registers. Kept together so the contract is
    /// readable in one place, and identical to the Android wrapper's.
    private enum Handler {
        static let credentials = "proximity.credentials"
        static let sign = "proximity.sign"
        static let consent = "proximity.consent"
        static let readerTrust = "proximity.readerTrust"
        static let step = "proximity.step"
        static let complete = "proximity.complete"
    }

    private let calls: PageCallHost

    private let log = Logger(with: ProximityBridge.self)

    private var peripheral: BlePeripheralServer?
    private var central: BleCentralClient?

    /// Bumped by every `start`. A transport torn down by the next `start` can
    /// still have work in flight, and its callbacks would otherwise report the
    /// old session's outcome to the page and tear down the new transport. Only
    /// touched on the main queue.
    private var generation = 0

    init(calls: PageCallHost) {
        self.calls = calls
    }

    // MARK: The page's side of the bridge

    /**
     Starts a session and returns the engagement for the page to render.

     Returns as soon as the transport is up: the session itself continues in
     the background and reports through `proximity.step` and
     `proximity.complete`. Callers get `{ mdocUri, mode }`, base64-encoded
     JSON like every other proximity payload.
     */
    func start(_ paramsJson: String?) throws -> Data {
        stop()

        let mode = Self.parseMode(paramsJson, log: log)

        generation += 1
        let session = generation

        // Advertise ONLY the role actually started. Offering both and serving
        // one means a reader that picks the other UUID out of the QR
        // engagement connects to nothing — the engagement would be lying
        // about what this device answers on.
        let engagement = try DeviceEngagement.create(
            supportsCentralClientMode: mode == .central,
            supportsPeripheralServerMode: mode == .peripheral)

        switch mode {
        case .peripheral:
            let server = BlePeripheralServer(
                engagement: engagement,
                getCredentials: { [weak self] in await self?.getCredentials() ?? [] },
                signPresentation: { [weak self] credentialId, disclosedClaims, sessionTranscript in
                    guard let self else { throw PageCallHost.CallError.noPage(Handler.sign) }

                    return try await self.signPresentation(
                        credentialId: credentialId,
                        disclosedClaims: disclosedClaims,
                        sessionTranscript: sessionTranscript)
                },
                requestConsent: { [weak self] docType, requestedClaims, families, readerTrust in
                    guard let self else { return .denied }

                    return await self.requestConsent(
                        docType: docType,
                        requestedClaims: requestedClaims,
                        matchingFamilies: families,
                        readerTrust: readerTrust)
                },
                evaluateReaderTrust: { [weak self] x5chain in
                    guard let self else {
                        return ReaderTrustResult(trusted: false, reason: "trust evaluation unavailable: no_page")
                    }

                    return await self.evaluateReaderTrust(x5chain)
                },
                filterEligible: Self.filterEligible,
                onStep: { [weak self] step in self?.onStep(step, session: session) },
                onLog: { [weak self] message in self?.log.debug("\(message)") },
                onComplete: { [weak self] success in self?.onComplete(success, session: session) })

            peripheral = server
            server.start()

        case .central:
            let client = BleCentralClient(
                engagement: engagement,
                getCredentials: { [weak self] in await self?.getCredentials() ?? [] },
                signPresentation: { [weak self] credentialId, disclosedClaims, sessionTranscript in
                    guard let self else { throw PageCallHost.CallError.noPage(Handler.sign) }

                    return try await self.signPresentation(
                        credentialId: credentialId,
                        disclosedClaims: disclosedClaims,
                        sessionTranscript: sessionTranscript)
                },
                requestConsent: { [weak self] docType, requestedClaims, families, readerTrust in
                    guard let self else { return .denied }

                    return await self.requestConsent(
                        docType: docType,
                        requestedClaims: requestedClaims,
                        matchingFamilies: families,
                        readerTrust: readerTrust)
                },
                evaluateReaderTrust: { [weak self] x5chain in
                    guard let self else {
                        return ReaderTrustResult(trusted: false, reason: "trust evaluation unavailable: no_page")
                    }

                    return await self.evaluateReaderTrust(x5chain)
                },
                filterEligible: Self.filterEligible,
                onStep: { [weak self] step in self?.onStep(step, session: session) },
                onLog: { [weak self] message in self?.log.debug("\(message)") },
                onComplete: { [weak self] success in self?.onComplete(success, session: session) })

            central = client
            client.start()
        }

        log.info("Proximity session started in \(mode.rawValue) mode.")

        return try Self.encode(["mdocUri": engagement.mdocUri, "mode": mode.rawValue])
    }

    /// Tears down whichever transport is running. Safe to call when none is.
    func stop() {
        peripheral?.stop()
        central?.stop()

        peripheral = nil
        central = nil
    }

    // MARK: The session's side of the bridge

    /**
     The page returns the credentials it is willing to present. It filters for
     eligibility itself, which is why `filterEligible` below is the identity:
     consumption policy and presentation history live in the page's own wallet
     state, so it is the only side that can apply them.
     */
    private func getCredentials() async -> [StoredCredential] {
        do {
            let reply = try await calls.call(Handler.credentials, payload: Self.nullPayload)

            return try JSONDecoder().decode([StoredCredential].self, from: reply)
        }
        catch {
            log.error("Could not get candidate credentials from the page: \(error.localizedDescription)")

            // The SDK treats an empty list as "nothing to present", which
            // ends the session cleanly. There is nothing better to do here:
            // the signature would have to come from the same page.
            return []
        }
    }

    /// See `getCredentials`: the page has already filtered.
    private static func filterEligible(_ candidates: [StoredCredential]) -> [StoredCredential] {
        candidates
    }

    /**
     The page signs, because the device key never leaves it. This is the
     callback that makes the bridge bidirectional; everything else here could
     have been one-way.
     */
    private func signPresentation(credentialId: Int64, disclosedClaims: [String]?, sessionTranscript: Data) async throws -> Data {
        var object: [String: Any] = [
            "credentialId": credentialId,
            "sessionTranscript": sessionTranscript.base64EncodedString(),
        ]

        // Spelled out rather than `disclosedClaims ?? NSNull()`: coercing an
        // Optional to `Any` yields a non-nil `Any` wrapping the nil, so `??`
        // would never fire and JSONSerialization would be handed a value it
        // cannot encode.
        if let disclosedClaims {
            object["disclosedClaims"] = disclosedClaims
        }
        else {
            object["disclosedClaims"] = NSNull()
        }

        let payload = try Self.encode(object)

        let reply = try await calls.call(Handler.sign, payload: payload)

        guard let answer = try JSONSerialization.jsonObject(with: reply) as? [String: Any],
              let encoded = answer["deviceResponse"] as? String,
              let deviceResponse = Data(base64Encoded: encoded),
              !deviceResponse.isEmpty
        else {
            // `Data(base64Encoded: "")` succeeds with zero bytes, so emptiness
            // has to be rejected explicitly or the reader gets an empty
            // response instead of an error.
            throw PageCallHost.CallError.pageFailed(Handler.sign, "returned no deviceResponse")
        }

        return deviceResponse
    }

    /**
     The page shows the prompt and returns a choice. Families are identified by
     their representative's credential id, which the page already knows from
     the list it supplied, so it can match its own display metadata without
     this bridge having to carry any.
     */
    private func requestConsent(
        docType: String,
        requestedClaims: [String],
        matchingFamilies: [CredentialFamily],
        readerTrust: ReaderTrustResult?
    ) async -> ProximityConsentResult {
        let families = matchingFamilies.map { family in
            [
                "credentialId": family.representative.id,
                "batchId": family.representative.batchId,
                "instances": family.instances.count,
            ] as [String: Any]
        }

        let trust: Any = readerTrust.map { trust -> [String: Any] in
            var object: [String: Any] = ["trusted": trust.trusted]
            object["reason"] = trust.reason ?? NSNull()
            object["entityName"] = trust.entityName ?? NSNull()

            return object
        } ?? NSNull()

        do {
            let payload = try Self.encode([
                "docType": docType,
                "requestedClaims": requestedClaims,
                "families": families,
                "readerTrust": trust,
            ])

            let reply = try await calls.call(Handler.consent, payload: payload)

            guard let object = try JSONSerialization.jsonObject(with: reply) as? [String: Any],
                  Self.bool(object["approved"])
            else {
                return .denied
            }

            // No falling back to the first family: the page chose from a list
            // this session handed it, so an absent or unrecognised id means
            // the answer is stale or malformed, and presenting *something*
            // would present a credential the user did not pick.
            guard let chosenId = Self.int64(object["credentialId"]),
                  let family = matchingFamilies.first(where: { $0.representative.id == chosenId })
            else {
                log.error("Consent was approved without naming a credential this session offered; denying.")

                return .denied
            }

            return .approved(family)
        }
        catch {
            log.error("Consent request failed: \(error.localizedDescription)")

            // Fail closed: an unanswered consent prompt is not consent.
            return .denied
        }
    }

    /**
     REVIEW POINT. Reader trust belongs on this side of the bridge, not the
     page's: both clients ask go-trust for the same decision, but only a
     native client has a fallback when go-trust is unreachable, and a
     checkpoint is exactly where it is unreachable.

     It is a callback here because the SDK's own reader-trust evaluation —
     AuthZEN against go-trust with local certificate-path validation as the
     fallback, including the distinction between a reader the backend refused
     and a backend that could not be reached — lives in `SirosWallet`
     (`SirosWallet+MdocTrust.swift`), which is only reachable through the
     wallet facade, and a web-view host deliberately does not construct one.
     Until that evaluation is reachable without it, this defers to the page,
     which means an offline session cannot make a trust decision at all.

     The Android wrapper is in exactly the same position, for the same reason.
     */
    private func evaluateReaderTrust(_ x5chain: [[UInt8]]) async -> ReaderTrustResult {
        do {
            let payload = try Self.encode([
                "x5chain": x5chain.map { Data($0).base64EncodedString() },
            ])

            let reply = try await calls.call(Handler.readerTrust, payload: payload)

            guard let object = try JSONSerialization.jsonObject(with: reply) as? [String: Any] else {
                throw PageCallHost.CallError.badReply(Handler.readerTrust)
            }

            return ReaderTrustResult(
                trusted: Self.bool(object["trusted"]),
                reason: object["reason"] as? String,
                entityName: object["entityName"] as? String)
        }
        catch {
            // Fail closed: an unanswered trust question is not a trusted reader.
            log.error("Reader trust evaluation failed; treating the reader as untrusted: \(error.localizedDescription)")

            return ReaderTrustResult(trusted: false, reason: "trust evaluation unavailable: \(error.localizedDescription)")
        }
    }

    /**
     The SDK reports from whichever thread it is on — `BleCentralClient` can
     finish from its own sending task — while `start` and `stop` run on the
     main queue with the page handlers. Land everything there, both to avoid
     racing over `peripheral`/`central` and to read `generation` consistently.
     */
    private func onStep(_ step: String, session: Int) {
        DispatchQueue.main.async {
            guard self.generation == session else {
                return self.log.debug("Ignoring step '\(step)' from a replaced session.")
            }

            guard let payload = try? Self.encode(["step": step]) else { return }

            self.calls.notify(Handler.step, payload: payload)
        }
    }

    private func onComplete(_ success: Bool, session: Int) {
        DispatchQueue.main.async {
            guard self.generation == session else {
                return self.log.debug("Ignoring completion from a replaced session.")
            }

            if let payload = try? Self.encode(["success": success]) {
                self.calls.notify(Handler.complete, payload: payload)
            }

            self.stop()
        }
    }

    // MARK: Helpers

    /// `null`, as the page's `__invoke__` will decode it. The credentials
    /// handler takes no arguments, and a payload is not optional on the wire.
    private static let nullPayload = Data("null".utf8)

    private static func encode(_ value: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed])
    }

    /// JSON `true` and the string `"true"` both mean yes, matching how the
    /// Android wrapper reads the same replies.
    private static func bool(_ value: Any?) -> Bool {
        if let value = value as? Bool {
            return value
        }

        if let value = value as? String {
            return value.lowercased() == "true"
        }

        return false
    }

    private static func int64(_ value: Any?) -> Int64? {
        if let value = value as? NSNumber {
            return value.int64Value
        }

        if let value = value as? String {
            return Int64(value)
        }

        return nil
    }

    private static func parseMode(_ paramsJson: String?, log: Logger) -> Mode {
        guard let paramsJson,
              let data = paramsJson.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let requested = object["mode"] as? String,
              !requested.isEmpty
        else {
            return .peripheral
        }

        guard let mode = Mode(rawValue: requested.lowercased()) else {
            log.warning("Unknown proximity mode '\(requested)'; using peripheral server mode.")

            return .peripheral
        }

        return mode
    }
}
