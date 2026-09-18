//
//  WebView.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-11-29.
//

import SwiftUI
@preconcurrency import WebKit
import OSLog

struct WebView: UIViewRepresentable {

    static let isSecureTextEntry = "__isSecureTextEntry__"

    let url: URL
    let model: BridgeModel

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url, model: model)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        var url: URL
        let model: BridgeModel

        /// ISO 18013-5 proximity, hosted by the SDK. Replaces the eight
        /// `bluetooth*` page handlers this class used to expose, which handed
        /// raw GATT to the page and left it to run the protocol. Created with
        /// the web view, since it needs to call back into the page.
        private var proximity: ProximityBridge?

        private let log = Logger(with: Coordinator.self)

        init(url: URL, model: BridgeModel) {
            self.url = url
            self.model = model
        }
        
        lazy var wkWebView: WKWebView = {
            let ucc = WKUserContentController()

            ucc.addUserScript(.sharedScript!)

            ucc.addUserScript(.bundledScript(named: "Bridge", ["isLocked": "\(Lock.isLocked)"])!)

            // Webauthn
            ucc.addPageHandler(named: "__webauthn_create_interface__") { [weak self] message in
                return try await self?.model.didReceiveCreate(message)
            }

            ucc.addPageHandler(named: "__webauthn_get_interface__") { [weak self] message in
                return try await self?.model.didReceiveGet(message)
            }

            ucc.addPageHandler(named: "__login_status_changed__") { [weak self] message in
                return try await self?.model.loginStatusChanged(message)
            }

            // Scan Physical ID (FaceTec). Fire-and-forget from the JS side; result
            // (credentialOfferURI) is fed back via model.loadURLCallback on success.
            ucc.addPageHandler(named: "__startScanPhysicalId__") { [weak self] message in
                return try await self?.model.startScanPhysicalId(message)
            }

            ucc.addUserScript(.nativeWrapperScript!)


            // Proximity (ISO 18013-5)
            ucc.addPageHandler(named: "__proximityStart__") { [weak self] message in
                self?.log.debug("⚙️ Proximity start: \(message.stringBody ?? "(unknown encoding)")")

                guard let proximity = self?.proximity else {
                    throw Errors.proximityUnavailable
                }

                return try proximity.start(message.stringBody).base64EncodedString()
            }

            ucc.addPageHandler(named: "__proximityStop__") { [weak self] _ in
                self?.log.debug("⚙️ Proximity stop")

                self?.proximity?.stop()

                // Base64 JSON `true`, so the page decodes every proximity
                // reply the same way.
                return Data("true".utf8).base64EncodedString()
            }



            let configuration = WKWebViewConfiguration()
            configuration.limitsNavigationsToAppBoundDomains = true
            configuration.userContentController = ucc

            let wkWebView = WKWebView(frame: .zero, configuration: configuration)

            proximity = ProximityBridge(calls: PageCallHost(webView: wkWebView))

            model.loadURLCallback = { url in
                wkWebView.load(URLRequest(url: url))
            }

            let request = URLRequest(url: url)

            wkWebView.isInspectable = true
            wkWebView.navigationDelegate = self
            wkWebView.uiDelegate = self
            wkWebView.load(request)

            return wkWebView
        }()
        

        // MARK: WKNavigationDelegate

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void)
        {
            if let url = navigationAction.request.url {

                log.info("Decide Policy for URL: \(url)")

                // Open all foreign web pages and app schemes like "eid" for the AusweisApp
                // externally. Only wwWallet code is allowed inside the app.
                if url.scheme != self.url.scheme || url.host != self.url.host {
                    UIApplication.shared.open(url)

                    return decisionHandler(.cancel)
                }
            }

            decisionHandler(.allow)
        }


        // MARK: WKUIDelegate

        func webView(
            _ webView: WKWebView,
            runJavaScriptAlertPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo
        ) async {
            await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

                alert.addAction(.init(title: NSLocalizedString("Ok", comment: ""), style: .default) { _ in
                    continuation.resume()
                })

                webView.window?.rootViewController?.top.present(alert, animated: true)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptTextInputPanelWithPrompt prompt: String,
            defaultText: String?,
            initiatedByFrame frame: WKFrameInfo
        ) async -> String? {
            await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)

                alert.addAction(.init(title: NSLocalizedString("Ok", comment: ""), style: .default) { _ in
                    continuation.resume(returning: alert.textFields?.first?.text)
                })

                alert.addAction(.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                    continuation.resume(returning: nil)
                })

                alert.addTextField { tf in
                    if defaultText == WebView.isSecureTextEntry {
                        tf.isSecureTextEntry = true
                    }
                    else {
                        tf.placeholder = defaultText
                    }
                }

                webView.window?.rootViewController?.top.present(alert, animated: true)
            }
        }

        func webView(
            _ webView: WKWebView,
            runJavaScriptConfirmPanelWithMessage message: String,
            initiatedByFrame frame: WKFrameInfo
        ) async -> Bool {
            await withCheckedContinuation { continuation in
                let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)

                alert.addAction(.init(title: NSLocalizedString("Ok", comment: ""), style: .default) { _ in
                    continuation.resume(returning: true)
                })

                alert.addAction(.init(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { _ in
                    continuation.resume(returning: false)
                })

                webView.window?.rootViewController?.top.present(alert, animated: true)
            }
        }
    }
    
    func makeUIView(context: Context) -> WKWebView {
        return context.coordinator.wkWebView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.uiDelegate = context.coordinator

        // When the host changes, update the coordinator and reload the web page.
        if url.host != context.coordinator.url.host {
            context.coordinator.url = url

            if webView.url?.host != url.host {
                webView.load(URLRequest(url: url))
            }
        }
    }
}
