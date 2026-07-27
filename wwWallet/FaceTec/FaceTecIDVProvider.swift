//
//  FaceTecIDVProvider.swift
//  wwWallet
//
//  Drives a full FaceTec Photo ID Match session and returns the resulting
//  credential offer URI on success. Ports wallet-android-wrapper's
//  PhotoIdMatchActivity + PhotoIdMatchSessionRequestProcessor flow to iOS.
//
//  FaceTec's integration contract is a single opaque Session Request/Response
//  Blob relay (see FaceTecPhotoIDMatchProcessor below) — not a generic
//  session-token/liveness/document REST contract, so this intentionally does
//  not go through any generic "biometric capture delegate" abstraction.
//

import Foundation
import UIKit
import OSLog
#if canImport(FaceTecSDK)
import FaceTecSDK

/// Wraps the FaceTec SDK's Photo ID Match flow behind a single async call
/// that returns the credential offer URI issued by facetec-api on success.
final class FaceTecIDVProvider: @unchecked Sendable {

    struct Config {
        /// facetec-api's `/v1/process-request` endpoint (Config.xcconfig's
        /// FACETEC_API_BASE_URL).
        let apiURL: URL
        /// Bearer token for facetec-api (Config.xcconfig's
        /// FACETEC_API_BEARER_TOKEN).
        let bearerToken: String
        /// FaceTec's public production-key identifier for this app
        /// (FaceTecConfig.deviceKeyIdentifier).
        let deviceKeyIdentifier: String
    }

    private let config: Config
    private let log = Logger(for: FaceTecIDVProvider.self)

    init(config: Config) {
        self.config = config
    }

    /// FaceTec's own device/OS compatibility checks run internally during
    /// `initializeWithSessionRequest`; there's no separate up-front check to
    /// perform here. Kept as a method (rather than a constant) to match the
    /// shape callers expect from other IDV providers.
    func isAvailable() -> Bool {
        true
    }

    /// Presents the FaceTec capture UI on `presentingViewController` and
    /// drives the full liveness + Photo ID Match flow. Returns the
    /// `credentialOfferURI` issued by facetec-api once the backend accepts
    /// the match; throws on cancellation, SDK failure, or if facetec-api
    /// never issued an offer.
    @MainActor
    func startVerification(presentingViewController: UIViewController) async throws -> String {
        let processor = FaceTecPhotoIDMatchProcessor(config: config, log: log)

        // Deliberately not `CheckedContinuation<FaceTecSDKInstance, Error>` /
        // `Result<FaceTecSDKInstance, Error>`: specializing a generic Swift
        // type over FaceTecSDKInstance forces the compiler to emit a direct
        // reference to `_OBJC_CLASS_$_FaceTecSDKInstance`, which FaceTec's
        // shipped xcframework doesn't export (only plain, non-generic
        // ObjC-style usage of the type — as FaceTec's own sample app does —
        // resolves at link time).
        var sdkInstanceBox: FaceTecSDKInstance?
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            FaceTec.sdk.initializeWithSessionRequest(
                deviceKeyIdentifier: config.deviceKeyIdentifier,
                sessionRequestProcessor: processor,
                completion: FaceTecInitializeCallbackBox(
                    onSuccess: { sdkInstance in
                        sdkInstanceBox = sdkInstance
                        continuation.resume()
                    },
                    onError: { _ in
                        continuation.resume(throwing: Errors.faceTecInitializationFailed)
                    }
                )
            )
        }
        guard let sdkInstance = sdkInstanceBox else {
            throw Errors.faceTecInitializationFailed
        }

        // Must run only after initializeWithSessionRequest succeeds — matches
        // FaceTec's own sample app (SampleAppViewController.onFaceTecSDKInitializeSuccess),
        // which sets these up inside the success callback, not beforehand.
        // Calling setCustomization/configureOCRLocalization before the SDK
        // finishes initializing crashes inside FaceTecSDK's own code (writes
        // into internal state that doesn't exist yet).
        FaceTecConfig.configureOCRLocalization()
        FaceTec.sdk.setCustomization(FaceTecConfig.customization())

        let sessionViewController = sdkInstance.start3DLivenessThen3D2DPhotoIDMatch(with: processor)
        presentingViewController.present(sessionViewController, animated: true)

        let status = await processor.waitForExit()

        guard status == .sessionCompleted else {
            log.info("FaceTec session ended without completing: \(String(describing: status))")
            throw Errors.faceTecCancelled
        }

        guard let credentialOfferURI = processor.credentialOfferURI else {
            throw Errors.faceTecNoCredentialOffer
        }

        return credentialOfferURI
    }
}

/// Relays FaceTec SDK Session Request/Response Blobs to facetec-api's
/// `/v1/process-request`, which proxies them to the FaceTec Server and
/// applies local policy to decide whether a successful Photo ID Match is
/// accepted.
///
/// Per FaceTec's integration contract, `onSessionRequest` performs only the
/// network call and the minimum bookkeeping needed to relay its result back
/// into the SDK — no other app logic or UI changes are allowed here.
///
/// Request/response bodies are opaque encrypted blobs to FaceTec Server and
/// are never logged, to keep this client's exposure to biometric data as
/// small as possible.
private final class FaceTecPhotoIDMatchProcessor: NSObject, FaceTecSessionRequestProcessor, @unchecked Sendable {

    private let config: FaceTecIDVProvider.Config
    private let log: Logger

    private(set) var credentialOfferURI: String?

    private var exitContinuation: CheckedContinuation<FaceTecSessionStatus, Never>?

    init(config: FaceTecIDVProvider.Config, log: Logger) {
        self.config = config
        self.log = log
    }

    /// Suspends until `onFaceTecExit` is called by the SDK.
    func waitForExit() async -> FaceTecSessionStatus {
        await withCheckedContinuation { continuation in
            self.exitContinuation = continuation
        }
    }

    func onSessionRequest(sessionRequestBlob: String, sessionRequestCallback: FaceTecSessionRequestProcessorCallback) {
        // FaceTec's own reference integration pins its URLSession delegate
        // queue to `.main` (SampleAppNetworkingRequest.swift) so every call
        // back into `sessionRequestCallback` happens on the main thread.
        // `URLSession.shared.data(for:)` resumes on an arbitrary background
        // executor after `await`, so without `@MainActor` here we'd be
        // calling processResponse/abortOnCatastrophicError off the main
        // thread — which is very likely what corrupted FaceTec's internal
        // state and caused the crash during initialization.
        Task { @MainActor in
            do {
                var request = URLRequest(url: config.apiURL)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(config.bearerToken)", forHTTPHeaderField: "Authorization")
                request.httpBody = try JSONSerialization.data(withJSONObject: ["requestBlob": sessionRequestBlob])

                let (data, response) = try await URLSession.shared.data(for: request)

                guard let http = response as? HTTPURLResponse else {
                    log.error("process-request: no HTTP response.")
                    sessionRequestCallback.abortOnCatastrophicError()
                    return
                }

                log.info("process-request HTTP status: \(http.statusCode)")

                guard (200..<300).contains(http.statusCode) else {
                    sessionRequestCallback.abortOnCatastrophicError()
                    return
                }

                guard
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let responseBlob = json["responseBlob"] as? String
                else {
                    log.error("process-request: response missing responseBlob.")
                    sessionRequestCallback.abortOnCatastrophicError()
                    return
                }

                if let offerURI = json["credentialOfferURI"] as? String, !offerURI.isEmpty {
                    credentialOfferURI = offerURI
                }

                sessionRequestCallback.processResponse(responseBlob)
            }
            catch {
                log.error("facetec-api process-request call failed: \(error)")
                sessionRequestCallback.abortOnCatastrophicError()
            }
        }
    }

    func onFaceTecExit(sessionResult: FaceTecSessionResult) {
        exitContinuation?.resume(returning: sessionResult.sessionStatus)
        exitContinuation = nil
    }
}

/// Bridges FaceTec's `FaceTecInitializeCallback` delegate protocol to a pair
/// of completion closures so `initializeWithSessionRequest` can be awaited.
///
/// Uses two plain closures rather than a single `Result<FaceTecSDKInstance,
/// Error>` one deliberately — see the comment at the call site in
/// `startVerification`.
private final class FaceTecInitializeCallbackBox: NSObject, FaceTecInitializeCallback {

    private let onSuccess: (FaceTecSDKInstance) -> Void
    private let onError: (FaceTecInitializationError) -> Void

    init(onSuccess: @escaping (FaceTecSDKInstance) -> Void, onError: @escaping (FaceTecInitializationError) -> Void) {
        self.onSuccess = onSuccess
        self.onError = onError
    }

    func onFaceTecSDKInitializeSuccess(sdkInstance: FaceTecSDKInstance) {
        onSuccess(sdkInstance)
    }

    func onFaceTecSDKInitializeError(error: FaceTecInitializationError) {
        onError(error)
    }
}
#endif
