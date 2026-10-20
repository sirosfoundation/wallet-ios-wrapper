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
#if canImport(FaceTecSDK)
import FaceTecSDK
#endif

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
        var conn: SmartCardConnection? = nil

        do {
            let sb = await message.stringBody
            log.debug("\(sb ?? "(nil)")")

            let request: CreateRequestWrapper = try await message.decode()

            // Use a wired connection, if the user plugged in a key in the meantime,
            // otherwise initiate a NFC connection.
            if let wired = await WiredConnectionManager.shared.wiredConnection {
                conn = wired
            }
            else {
                conn = try await NFCSmartCardConnection.makeConnection()
            }

            let session = try await CTAP2.Session.makeSession(connection: conn!)

            let r = request.request
            var token: CTAP2.Token? = nil

            if let pin = pin, !pin.isEmpty {
                self.pin = pin // Refresh timer
                token = try await session.getPinUVToken(using: .pin(pin), permissions: .makeCredential, rpId: r.rp.id)
            }

            guard let clientData = r.clientData else {
                throw Errors.cannotCreateClientDataHash
            }
            let clientDataJson = try WebAuthnClientDataJson(clientData)

            guard let user = r.user.entity else {
                throw Errors.cannotCreateUserEntity
            }

            let prfs = try await PrfExtensions(session, r.extensions)
            let extensions = try prfs.makeCredentialInput()

            let response = try await session.makeCredential(
                parameters: .init(
                    clientDataHash: clientDataJson.hash,
                    rp: r.rp.entity,
                    user: user,
                    pubKeyCredParams: r.pubKeyCredParams.map({ $0.algorithm }),
                    excludeList: r.excludeCredentials?.compactMap({ $0.descriptor }),
                    extensions: extensions,
                    rk: r.rk
                ),
                token: token).value

            let credentials = try Credentials(clientDataJson, response, prfs)

            let json = String(data: try JSONEncoder().encode(ResponseWrapper(credentials, "create")), encoding: .utf8)

            await conn?.close(error: nil)

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
        var conn: SmartCardConnection? = nil

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

            // Use a wired connection, if the user plugged in a key in the meantime,
            // otherwise initiate a NFC connection.
            if let wired = await WiredConnectionManager.shared.wiredConnection {
                conn = wired
            }
            else {
                conn = try await NFCSmartCardConnection.makeConnection()
            }

            let session = try await CTAP2.Session.makeSession(connection: conn!)

            let r = request.request
            var token: CTAP2.Token? = nil

            // For subsequent calls, we have the PIN available and try to verify it.
            if needsPin {
                pin = pin // Refresh timer
                token = try await session.getPinUVToken(using: .pin(pin ?? ""), permissions: .getAssertion, rpId: r.rpId)
            }

            guard let clientData = r.clientData else {
                throw Errors.cannotCreateClientDataHash
            }
            let clientDataJson = try WebAuthnClientDataJson(clientData)

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
                    clientDataHash: clientDataJson.hash,
                    allowList: allowList,
                    extensions: extensions
                ),
                token: token).value

            // There's multiple credentials on the YubiKey. Fetch their IDs and
            // show it to the user for selection.
            if let credCount = response.numberOfCredentials, credCount > 1 {
                var responses = [response]

                for _ in 1 ..< credCount {
                    for try await nextResponse in await session.getNextAssertion() {
                        if case .finished(let response) = nextResponse {
                            responses.append(response)
                        }
                    }
                }

                if responses.count > 1 {
                    throw Errors.multipleCredentials(responses)
                }
            }

            let credentials = try Credentials(clientDataJson, response, prfs)

            let json = String(data: try JSONEncoder().encode(ResponseWrapper(credentials, "get")), encoding: .utf8)

            log.debug("\(json ?? "(nil)")")

            await conn?.close(error: nil)

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
                await conn?.close(error: nil)

                log.error("\(error)")

                try await Task.sleep(nanoseconds: 1 * NSEC_PER_SEC)

                await acquireCredential(message, responses)

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

    func startScanPhysicalId(_ message: WKScriptMessage) async throws -> Any? {
        log.debug("Start scan physical ID")

#if canImport(FaceTecSDK)
        guard let baseURL = URL(string: Config.faceTecApiBaseUrl)
        else {
            throw Errors.faceTecNotConfigured
        }

        let bearerToken = Config.faceTecApiBearerToken

        guard let presentingVc = await message.webView?.window?.rootViewController?.top else {
            throw Errors.faceTecNoPresenter
        }

        let provider = FaceTecIDVProvider(config: .init(
            apiURL: baseURL,
            bearerToken: bearerToken,
            deviceKeyIdentifier: FaceTecConfig.deviceKeyIdentifier
        ))

        guard provider.isAvailable() else {
            throw Errors.faceTecNotAvailable
        }

        // The web app ignores this call's result, so an error the user can act
        // on is shown natively; anything else is only thrown, as before.
        guard provider.isNFCReadingAvailable() else {
            await showAlert(Errors.faceTecNFCUnavailable, on: presentingVc)
            throw Errors.faceTecNFCUnavailable
        }

        let credentialOfferURI: String
        do {
            credentialOfferURI = try await provider.startVerification(presentingViewController: presentingVc)
        }
        catch Errors.faceTecIssuanceRefused(let code) {
            let error = Errors.faceTecIssuanceRefused(code: code)
            await showAlert(error, on: presentingVc, title: NSLocalizedString("No credential issued", comment: ""))
            throw error
        }

        // wallet-frontend's UriHandlerProvider expects the credential offer's
        // query string to arrive at its tenant-scoped `cb` route — it detects
        // `openid-credential-offer://` by inspecting `window.location.href`
        // and rewrites to `buildPath('cb?<query>')` itself, but WKWebView
        // can't navigate to a non-http(s) scheme at all, so that JS never
        // runs. Replicate the same transform natively: derive the tenant
        // base (`/id/<tenant>/`) from the *current* page's path — not just
        // its last component, which breaks on trailing slashes (e.g. the Add
        // Credentials page's `/id/default/add/`) — and append `cb`.
        if
            let currentURL = await message.webView?.url,
            var targetComponents = URLComponents(url: currentURL, resolvingAgainstBaseURL: false),
            let offerComponents = URLComponents(string: credentialOfferURI)
        {
            let pathComponents = targetComponents.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
            if let idIndex = pathComponents.firstIndex(of: "id"), idIndex + 1 < pathComponents.count {
                let tenantBase = pathComponents[0...(idIndex + 1)]
                targetComponents.path = "/" + tenantBase.joined(separator: "/") + "/cb"
            } else {
                targetComponents.path = "/cb"
            }
            targetComponents.query = offerComponents.query

            if let url = targetComponents.url {
                openUrl(url)
            }
        }

        return nil
#else
        // FaceTecSDK is not linked into this build target yet (it's added via
        // the local Vendor/FaceTecSDK package in Xcode's Package Dependencies).
        log.error("FaceTecSDK not linked into this build yet.")

        throw Errors.faceTecNotAvailable
#endif
    }

    /// Presents `error` as a simple alert and waits until the user dismisses
    /// it. The bridge call waits on this, so it must always return.
    ///
    /// `viewController` is the one that presented the FaceTec session, which
    /// may still be dismissing when `onFaceTecExit` fires; UIKit refuses to
    /// present from a controller in that state. So this waits (bounded) for
    /// the dismissal to finish and presents from whatever is then on top; if
    /// UIKit still refuses, it gives up rather than leave the call suspended.
    @MainActor
    private func showAlert(_ error: Errors, on viewController: UIViewController, title: String? = nil) async {
        var waited = 0
        while viewController.presentedViewController?.isBeingDismissed == true, waited < 30 {
            try? await Task.sleep(nanoseconds: 100_000_000)
            waited += 1
        }

        let once = AlertContinuation()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            once.continuation = continuation

            let alert = UIAlertController(title: title, message: error.localizedDescription, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { _ in
                once.resume()
            })

            viewController.top.present(alert, animated: true)

            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if alert.presentingViewController == nil {
                    self.log.error("Could not present the FaceTec refusal alert: \(error.localizedDescription)")
                    once.resume()
                }
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
    private func acquireCredential(_ message: WKScriptMessage, _ responses: [CTAP2.GetAssertion.Response]) async {
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

/// Resumes a continuation at most once, from whichever of the alert's OK
/// button or its presentation check gets there first.
@MainActor
private final class AlertContinuation {
    var continuation: CheckedContinuation<Void, Never>?

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}
