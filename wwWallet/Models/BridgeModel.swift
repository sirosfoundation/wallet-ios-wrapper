//
//  BridgeModel.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//


import SwiftUI
import YubiKit
import WebKit
import OSLog

@Observable class BridgeModel {

    var receivedMessage: String?
    var sentMessage: String?

    @MainActor
    var loadURLCallback: ((URL) -> Void)?

    private static let pinCacheTimeoutNs = 60 * NSEC_PER_SEC

    private var pinResetTask: Task<Void, any Error>?

    private(set) var pin: String? {
        didSet {
            pinResetTask?.cancel()

            if pin != nil {
                pinResetTask = Task {
                    try await Task.sleep(nanoseconds: Self.pinCacheTimeoutNs)
                    pin = nil
                    log.debug("PIN cleared after timeout.")
                }
            }
        }
    }

    private var selectedCredential: WebAuthn.CredentialDescriptor? = nil

    private let log: Logger = Logger(for: BridgeModel.self)


    func openUrl(_ url: URL) {
        Task {
            await MainActor.run {
                loadURLCallback?(url)
            }
        }
    }

    func didReceiveCreate(_ message: WKScriptMessage) async throws -> [String: String?] {
        var conn: NFCSmartCardConnection? = nil

        do {
            let sb = await message.stringBody
            log.debug("\(sb ?? "(nil)")")

            let request: CreateRequestWrapper = try await message.decode()

            conn = try await NFCSmartCardConnection.makeConnection()

            let session = try await CTAP2.Session.makeSession(connection: conn!)

            let r = request.request
            var token: CTAP2.Token? = nil

            if let pin = pin, !pin.isEmpty {
                self.pin = pin // Refresh timer
                token = try await session.getPinUVToken(using: .pin(pin), permissions: .makeCredential, rpId: r.rp.id)
            }

            guard let clientDataHash = try r.clientData?.clientDataHash else {
                throw Errors.cannotCreateClientDataHash
            }

            guard let user = r.user.entity else {
                throw Errors.cannotCreateUserEntity
            }

            let prfs = try await PrfExtensions(session, r.extensions)
            let extensions = try prfs.makeCredentialInput()

            let response = try await session.makeCredential(
                parameters: .init(
                    clientDataHash: clientDataHash,
                    rp: r.rp.entity,
                    user: user,
                    pubKeyCredParams: r.pubKeyCredParams.map({ $0.algorithm }),
                    excludeList: r.excludeCredentials?.compactMap({ $0.descriptor }),
                    extensions: extensions,
                    rk: r.rk
                ),
                token: token).value

            let credentials = try Credentials(r.clientData!, response, prfs)

            let json = String(data: try JSONEncoder().encode(ResponseWrapper(credentials, "create")), encoding: .utf8)

            await conn?.close()

            log.debug("\(json ?? "(nil)")")

            return ["data": json]
        }
        catch {
            switch error {
            case CTAP2.SessionError.ctapError(let error, source: _):
                await conn?.close(error: error)

                switch error {
                case CTAP2.Error.pinInvalid, CTAP2.Error.puatRequired:
                    await acquirePin(message)

                    // User cancelled.
                    if pin?.isEmpty ?? true {
                        return [:]
                    }

                    return try await didReceiveCreate(message)

                case CTAP2.Error.credentialExcluded:
                    // Special treatment for unclear reasons.
                    throw Errors.error0x19

                default:
                    throw error
                }

            default:
                await conn?.close(error: error)

                throw error
            }
        }
    }

    func didReceiveGet(_ message: WKScriptMessage) async throws -> [String: String?] {
        var conn: NFCSmartCardConnection? = nil

        do {
            let sb = await message.stringBody
            log.debug("\(sb ?? "(nil)")")

            let request: GetRequestWrapper = try await message.decode()

            // If wwWallet wants user verification, we *do need to use a PIN*.
            // For subsequent calls, we then have the PIN available.
            // See https://developers.yubico.com/WebAuthn/WebAuthn_Developer_Guide/User_Presence_vs_User_Verification.html
            //
            // Also, the PRF extension *always requires* user verification, so force it,
            // even when the frontend didn't explicitly ask for it.
            let needsPin = request.request.userVerification?.lowercased() == "required" || request.request.extensions?["prf"] != nil

            // At the first time, this PIN will be empty, so we throw right away
            // in order to trigger the PIN entry UI.
            if needsPin && (pin?.isEmpty ?? true) {
                // Error message unneeded, because it will not be shown when we throw before session initialization.
                throw CTAP2.SessionError.ctapError(CTAP2.Error.puatRequired, source: .here())
            }

            conn = try await NFCSmartCardConnection.makeConnection()

            let session = try await CTAP2.Session.makeSession(connection: conn!)

            let r = request.request
            var token: CTAP2.Token? = nil

            // For subsequent calls, we have the PIN available and try to verify it.
            if needsPin {
                pin = pin // Refresh timer
                token = try await session.getPinUVToken(using: .pin(pin ?? ""), permissions: .getAssertion, rpId: r.rpId)
            }

            guard let clientDataHash = try r.clientData?.clientDataHash else {
                throw Errors.cannotCreateClientDataHash
            }

            let prfs = try await PrfExtensions(session, r.extensions, r.allowCredentials)
            let extensions = try prfs.getAssertionInput()

            var allowList: [WebAuthn.CredentialDescriptor]? = nil

            // If the user selected a specific Passkey, use that.
            if let selectedCredential = selectedCredential {
                allowList = [selectedCredential]
            }
            else if let credentials = r.allowCredentials {
                allowList = credentials.compactMap({ $0.descriptor })
            }

            let response = try await session.getAssertion(
                parameters: .init(
                    rpId: r.rpId,
                    clientDataHash: clientDataHash,
                    allowList: allowList,
                    extensions: extensions
                ),
                token: token).value

            // There's multiple credentials on the YubiKey. Fetch their IDs and
            // show it to the user for selection.
            if response.numberOfCredentials ?? 1 > 1 {
                var responses = [response]

                for try await nextResponse in await session.getNextAssertion() {
                    if case .finished(let response) = nextResponse {
                        responses.append(response)
                    }
                }

                if responses.count > 1 {
                    throw Errors.multipleCredentials(responses)
                }
            }

            let credentials = try Credentials(r.clientData!, response, prfs)

            let json = String(data: try JSONEncoder().encode(ResponseWrapper(credentials, "get")), encoding: .utf8)

            log.debug("\(json ?? "(nil)")")

            await conn?.close()

            // Remove user selection again after use.
            selectedCredential = nil

            return ["data": json]
        }
        catch {
            switch error {
            case CTAP2.SessionError.ctapError(let error, source: _):
                await conn?.close(error: error)

                log.error("\(error)")

                switch error {
                case CTAP2.Error.pinInvalid, CTAP2.Error.puatRequired:
                    await acquirePin(message)

                    // User cancelled.
                    if pin?.isEmpty ?? true {
                        return [:]
                    }

                    return try await didReceiveGet(message)

                default:
                    selectedCredential = nil
                    throw error
                }

            case Errors.multipleCredentials(let responses):
                await conn?.close()

                log.error("\(error)")

                try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)

                await acquireUser(message, responses)

                if selectedCredential == nil {
                    // User cancelled.
                    return [:]
                }

                return try await didReceiveGet(message)

            default:
                await conn?.close(error: error)

                log.error("\(error)")

                selectedCredential = nil
                throw error
            }
        }
    }

    func loginStatusChanged(_ message: WKScriptMessage) async throws {
        if await message.stringBody == "unlocked" {
            try Lock.unlock()
        }
        else {
            try Lock.lock()
        }
    }

    private func acquirePin(_ message: WKScriptMessage) async {
        do {
            let value = try await message.webView?.callAsyncJavaScript(
                "return prompt(\"\(NSLocalizedString("Please enter your FIDO2/WebAuthn PIN.", comment: ""))\", \"\(WebView.isSecureTextEntry)\")",
                contentWorld: message.world)

            pin = value as? String
        }
        catch {
            pin = nil
        }
    }

    @MainActor
    private func acquireUser(_ message: WKScriptMessage, _ responses: [CTAP2.GetAssertion.Response]) async {
        selectedCredential = await withCheckedContinuation { continuation in
            if let topVc = message.webView?.window?.rootViewController?.top, !topVc.isBeingDismissed {
                let vc = CredentialSelectionViewController()
                vc.responses = responses
                vc.resultCallback = {
                    vc.resultCallback = nil // Remove circular reference so ARC can deinit view controller.

                    continuation.resume(returning: $0)
                }

                let navC = UINavigationController(rootViewController: vc)

                topVc.present(navC, animated: true)
            }
            else {
                continuation.resume(returning: nil)
            }
        }
    }
}
