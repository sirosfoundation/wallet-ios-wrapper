//
//  FaceTecConfig.swift
//  wwWallet
//
//  Static FaceTec SDK configuration for the Photo ID Match flow. Ports
//  wallet-android-wrapper's FaceTecConfig.kt 1:1 (same colors, same device
//  key) to iOS.
//
//  DEVICE_KEY_IDENTIFIER is the public production-key identifier issued by
//  FaceTec for this application (via the FaceTec Configuration Wizard) — it
//  is not a secret and is meant to ship inside the app, unlike the
//  facetec-api bearer token (see Config.xcconfig's FACETEC_API_BEARER_TOKEN).
//

import Foundation
import UIKit
import OSLog
#if canImport(FaceTecSDK)
import FaceTecSDK

enum FaceTecConfig {

    static let deviceKeyIdentifier = "dHrY0vwYRYn44JtJVHTNoBgvnaS5BGJw"

    private static let ocrCustomizationAsset = "FaceTec_OCR_Customization"

    private static let log = Logger(with: FaceTecConfig.self)

    static func customization() -> FaceTecCustomization {
        let outerBackgroundColor = UIColor(hex: "#ffffff")
        let frameColor = UIColor(hex: "#ffffff")
        let borderColor = UIColor(hex: "#1c4587")
        let ovalColor = UIColor(hex: "#1c4587")
        let textColor = UIColor(hex: "#0c0e11")
        let buttonAndFeedbackBarColor = UIColor(hex: "#1c4587")
        let buttonAndFeedbackBarTextColor = UIColor(hex: "#ffffff")
        let buttonColorHighlight = UIColor(hex: "#3e6198")
        let buttonColorDisabled = UIColor(hex: "#414141")

        let customization = FaceTecCustomization()

        customization.frameCustomization.cornerRadius = 20
        customization.frameCustomization.backgroundColor = frameColor
        customization.frameCustomization.borderColor = borderColor

        customization.overlayCustomization.brandingImage = UIImage(named: "FaceTec_your_app_logo")
        customization.overlayCustomization.backgroundColor = outerBackgroundColor

        customization.guidanceCustomization.backgroundColors = [frameColor, frameColor]
        customization.guidanceCustomization.foregroundColor = textColor
        customization.guidanceCustomization.buttonBackgroundNormalColor = buttonAndFeedbackBarColor
        customization.guidanceCustomization.buttonBackgroundDisabledColor = buttonColorDisabled
        customization.guidanceCustomization.buttonBackgroundHighlightColor = buttonColorHighlight
        customization.guidanceCustomization.buttonTextNormalColor = buttonAndFeedbackBarTextColor
        customization.guidanceCustomization.buttonTextDisabledColor = buttonAndFeedbackBarTextColor
        customization.guidanceCustomization.buttonTextHighlightColor = buttonAndFeedbackBarTextColor
        customization.guidanceCustomization.retryScreenImageBorderColor = borderColor
        customization.guidanceCustomization.retryScreenOvalStrokeColor = borderColor

        customization.ovalCustomization.strokeColor = ovalColor
        customization.ovalCustomization.progressColor1 = ovalColor
        customization.ovalCustomization.progressColor2 = ovalColor

        let feedbackBackgroundLayer = CAGradientLayer()
        feedbackBackgroundLayer.colors = [buttonAndFeedbackBarColor.cgColor, buttonAndFeedbackBarColor.cgColor]
        customization.feedbackCustomization.backgroundColor = feedbackBackgroundLayer
        customization.feedbackCustomization.textColor = buttonAndFeedbackBarTextColor

        customization.cancelButtonCustomization.customImage = UIImage(named: "FaceTec_cancel")
        customization.cancelButtonCustomization.location = .topLeft

        customization.resultScreenCustomization.backgroundColors = [frameColor, frameColor]
        customization.resultScreenCustomization.foregroundColor = textColor
        customization.resultScreenCustomization.activityIndicatorColor = buttonAndFeedbackBarColor
        customization.resultScreenCustomization.resultAnimationBackgroundColor = buttonAndFeedbackBarColor
        customization.resultScreenCustomization.resultAnimationForegroundColor = buttonAndFeedbackBarTextColor
        customization.resultScreenCustomization.uploadProgressFillColor = buttonAndFeedbackBarColor

        customization.securityWatermarkImage = .faceTec

        customization.idScanCustomization.selectionScreenBackgroundColors = [frameColor, frameColor]
        customization.idScanCustomization.selectionScreenForegroundColor = textColor
        customization.idScanCustomization.reviewScreenBackgroundColors = [frameColor, frameColor]
        customization.idScanCustomization.reviewScreenForegroundColor = buttonAndFeedbackBarTextColor
        customization.idScanCustomization.reviewScreenTextBackgroundColor = buttonAndFeedbackBarColor
        customization.idScanCustomization.captureScreenForegroundColor = buttonAndFeedbackBarTextColor
        customization.idScanCustomization.captureScreenTextBackgroundColor = buttonAndFeedbackBarColor
        customization.idScanCustomization.buttonBackgroundNormalColor = buttonAndFeedbackBarColor
        customization.idScanCustomization.buttonBackgroundDisabledColor = buttonColorDisabled
        customization.idScanCustomization.buttonBackgroundHighlightColor = buttonColorHighlight
        customization.idScanCustomization.buttonTextNormalColor = buttonAndFeedbackBarTextColor
        customization.idScanCustomization.buttonTextDisabledColor = buttonAndFeedbackBarTextColor
        customization.idScanCustomization.buttonTextHighlightColor = buttonAndFeedbackBarTextColor
        customization.idScanCustomization.captureScreenBackgroundColor = frameColor
        customization.idScanCustomization.captureFrameStrokeColor = borderColor

        return customization
    }

    /// Sets the localized group/field/placeholder strings for the ID Scan OCR
    /// Confirmation Screen. Uses FaceTec's own template asset, same as their
    /// Sample App and wallet-android-wrapper's FaceTecConfig.kt.
    static func configureOCRLocalization() {
        guard let url = Bundle.main.url(forResource: ocrCustomizationAsset, withExtension: "json") else {
            log.error("FaceTec OCR localization asset not found in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)

            guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                log.error("FaceTec OCR localization asset is not a JSON object.")
                return
            }

            FaceTec.sdk.configureOCRLocalization(dictionary: dictionary)
        }
        catch {
            log.error("Failed to load FaceTec OCR localization asset: \(error)")
        }
    }
}

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }

        self.init(red: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: CGFloat(a) / 255)
    }
}
#endif
