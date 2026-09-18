//
//  PageCallHost.swift
//  wwWallet
//

import Foundation
@preconcurrency import WebKit
import OSLog

/**
 Calls INTO the page and waits for an answer.

 The existing bridge only goes one way: the page posts to a
 `WKScriptMessageHandlerWithReply` and native answers. Hosting the mdoc
 protocol rather than forwarding bytes needs the other direction too, because
 the things the page still owns — the candidate credential list, the user's
 consent, a signature from a key that never leaves the page — are needed
 *during* a native session, not before it.

 ## Wire shape

 Native evaluates `nativeWrapper.__invoke__(name, payloadB64)` and awaits the
 promise it returns. Payloads are UTF-8 JSON in base64 in both directions, so
 quoting, newlines and the U+2028/U+2029 hazard all stop existing, and a
 binary payload needs no separate encoding.

 ## How this differs from the Android wrapper

 The page-facing contract is identical — same handler names, same payloads,
 same `nativeWrapper.onRequest(name, handler)` registration — but the
 plumbing underneath is about half the size, because `callAsyncJavaScript`
 awaits a returned promise for us. Android has to hand the page a call id,
 keep a pending map, expose `__reply__`/`__replyError__` back across the
 bridge, and invalidate outstanding calls on navigation. Here WebKit does the
 correlation, and a navigation destroys the JavaScript context, which fails
 the outstanding call on its own.

 The one thing it does not do is time out, so that is below. Like Android's
 `__cancel__`, the timeout only stops us waiting — a handler already running
 in the page keeps running, and its answer is dropped.
 */
final class PageCallHost {

    enum CallError: LocalizedError {

        /// The web view is gone, so there is no page to ask.
        case noPage(String)

        /// The page did not answer in time.
        case timedOut(String, Int)

        /// The page's handler threw, or there was none registered.
        case pageFailed(String, String)

        /// The page answered with something that is not base64 JSON.
        case badReply(String)

        var errorDescription: String? {
            switch self {
            case .noPage(let name):
                return "there is no page to answer '\(name)'"

            case .timedOut(let name, let ms):
                return "the page did not answer '\(name)' within \(ms)ms"

            case .pageFailed(let name, let message):
                return "the page failed '\(name)': \(message)"

            case .badReply(let name):
                return "the page's answer to '\(name)' was not base64 JSON"
            }
        }
    }

    /// Long enough that a consent prompt can wait for a person, short enough
    /// that a wedged page does not hold a reader's session open until the
    /// reader itself gives up. Same value as the Android wrapper.
    static let defaultTimeoutMs = 60_000

    /// `callAsyncJavaScript` wraps this in an async function whose parameters
    /// are the `arguments` dictionary's keys, so `await` and `return` work and
    /// nothing is interpolated into a string.
    private static let invokeBody = "return await window.nativeWrapper.__invoke__(name, payloadB64);"

    private static let notifyBody = "window.nativeWrapper.__notify__(name, payloadB64); return null;"

    private weak var webView: WKWebView?

    private let log = Logger(with: PageCallHost.self)

    init(webView: WKWebView) {
        self.webView = webView
    }

    /// Invokes `name` in the page and suspends until it answers.
    func call(_ name: String, payload: Data, timeoutMs: Int = PageCallHost.defaultTimeoutMs) async throws -> Data {
        let payloadB64 = payload.base64EncodedString()

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.main.async {
                guard let webView = self.webView else {
                    return continuation.resume(throwing: CallError.noPage(name))
                }

                // Only one of the two paths below may resume. Both run on the
                // main queue, so the flag needs no further synchronisation.
                var settled = false

                let timeout = DispatchWorkItem {
                    guard !settled else { return }
                    settled = true

                    continuation.resume(throwing: CallError.timedOut(name, timeoutMs))
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(timeoutMs), execute: timeout)

                webView.callAsyncJavaScript(
                    Self.invokeBody,
                    arguments: ["name": name, "payloadB64": payloadB64],
                    in: nil,
                    in: .page)
                { result in
                    guard !settled else { return }
                    settled = true
                    timeout.cancel()

                    switch result {
                    case .success(let value):
                        guard let encoded = value as? String,
                              let data = Data(base64Encoded: encoded)
                        else {
                            return continuation.resume(throwing: CallError.badReply(name))
                        }

                        continuation.resume(returning: data)

                    case .failure(let error):
                        continuation.resume(throwing: CallError.pageFailed(name, error.localizedDescription))
                    }
                }
            }
        }
    }

    /// Fire-and-forget. Used for progress and terminal notifications, where
    /// there is nothing to wait for.
    func notify(_ name: String, payload: Data) {
        let payloadB64 = payload.base64EncodedString()

        DispatchQueue.main.async {
            guard let webView = self.webView else {
                return self.log.debug("Dropped notification '\(name)': there is no page.")
            }

            webView.callAsyncJavaScript(
                Self.notifyBody,
                arguments: ["name": name, "payloadB64": payloadB64],
                in: nil,
                in: .page)
            { result in
                if case .failure(let error) = result {
                    self.log.debug("Notification '\(name)' failed: \(error.localizedDescription)")
                }
            }
        }
    }
}
