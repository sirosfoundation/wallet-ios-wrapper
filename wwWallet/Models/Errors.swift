//
//  Errors.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 11.04.25.
//

import Foundation
import YubiKit

enum Errors: LocalizedError {

    case cannotDecodeMessage
    case cannotCreateClientDataHash
    case cannotCreateUserEntity
    case error0x19
    case multipleCredentials(_ responses: [CTAP2.GetAssertion.Response])
    case faceTecNotAvailable
    case faceTecNotConfigured
    case faceTecNoPresenter
    case faceTecCancelled
    case faceTecNoCredentialOffer
    case faceTecInitializationFailed
    case faceTecNFCUnavailable
    /// The scan completed, but facetec-api issued no credential and said why
    /// in `credentialIssueErrorCode`.
    case faceTecIssuanceRefused(code: String)

    var errorDescription: String? {
        switch self {
        case .cannotDecodeMessage:
            return NSLocalizedString("Cannot decode message.", comment: "")

        case .cannotCreateClientDataHash:
            return NSLocalizedString("Cannot create clientDataHash", comment: "")

        case .cannotCreateUserEntity:
            return NSLocalizedString("Cannot create user entity", comment: "")

        case .error0x19:
            return "0x19"

        case .multipleCredentials(let responses):
            return "Multiple credentials available: \(responses.map({ $0.user?.fallbackName }))"

        case .faceTecNotAvailable:
            return NSLocalizedString("FaceTec Scan Physical ID is not available in this build.", comment: "")

        case .faceTecNotConfigured:
            return NSLocalizedString("FaceTec API base URL is not configured.", comment: "")

        case .faceTecNoPresenter:
            return NSLocalizedString("No view controller available to present FaceTec.", comment: "")

        case .faceTecCancelled:
            return NSLocalizedString("FaceTec verification was cancelled or did not complete.", comment: "")

        case .faceTecNoCredentialOffer:
            return NSLocalizedString("FaceTec verification completed, but no credential offer was issued.", comment: "")

        case .faceTecInitializationFailed:
            return NSLocalizedString("FaceTec SDK could not be initialized.", comment: "")

        case .faceTecNFCUnavailable:
            return NSLocalizedString("This device cannot read NFC. Reading the chip in your passport or ID card is required, so identity verification is not possible on this device.", comment: "")

        case .faceTecIssuanceRefused(let code):
            switch code {
            case "nfc_not_requested":
                return NSLocalizedString("This document cannot be verified by its chip. Please use an e-passport or an ID card whose chip can be read.", comment: "")

            case "nfc_device_not_capable":
                return NSLocalizedString("This device could not read the chip. Please try again.", comment: "")

            case "nfc_skipped":
                return NSLocalizedString("Reading the chip in your document is required. Please try again and hold your document against the top of the phone when asked.", comment: "")

            case "nfc_chip_read_failed":
                return NSLocalizedString("The chip in your document could not be read. Please try again and hold the document still against the top of the phone.", comment: "")

            case "nfc_not_authenticated":
                return NSLocalizedString("The chip in your document could not be verified, so no credential was issued.", comment: "")

            case "chip_photo_mismatch":
                return NSLocalizedString("Your face did not match the photo stored in your document's chip, so no credential was issued. Please try again, or use another identity document.", comment: "")

            case "chip_untrusted":
                return NSLocalizedString("The chip in your document could not be confirmed as issued by a recognised authority, so no credential was issued.", comment: "")

            case "policy_rejected":
                return NSLocalizedString("Your scan could not be accepted: your face did not match the document photo closely enough, or this type of document is not accepted. Please try again in good light, or use another identity document.", comment: "")

            case "match_failed":
                return NSLocalizedString("Your scan could not be checked. Please try again.", comment: "")

            case "issuance_failed":
                return NSLocalizedString("Your identity was verified, but the credential could not be issued. Please try again later.", comment: "")

            case "internal_error":
                return NSLocalizedString("Something went wrong on our side, so no credential was issued. Please try again later.", comment: "")

            case "liveness_failed":
                return NSLocalizedString("We could not confirm that a live person was in front of the camera, so no credential was issued. Please try again in good light, facing the camera.", comment: "")

            case "document_expired":
                return NSLocalizedString("This document has expired, so no credential was issued. Please use a valid identity document.", comment: "")

            case "document_unreadable":
                return NSLocalizedString("The document's details could not be read, so no credential was issued. Please try again, or use another identity document.", comment: "")

            default:
                return NSLocalizedString("Your identity could not be verified, so no credential was issued. Please try again.", comment: "")
            }
        }
    }
}

extension CTAP2.Error: @retroactive LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .pinInvalid:
            return NSLocalizedString("The provided PIN is invalid.", comment: "")

        case .pinNotSet:
            return NSLocalizedString("A PIN needs to be set.", comment: "")

        case .puatRequired:
            return NSLocalizedString("Please provide PIN.", comment: "")

        case .noCredentials:
            return NSLocalizedString("There is no passkey for this site on this security key. Please add one or find another method for accessing this site.", comment: "")

        case .pinAuthBlocked:
            return NSLocalizedString("PIN entry is temporarily blocked. Disconnect and reconnect the security key before trying again.", comment: "")

        case .pinBlocked:
            return NSLocalizedString("The security key PIN is blocked. Use another security key or consult your key's recovery instructions.", comment: "")

        case .pinPolicyViolation:
            return NSLocalizedString("The PIN does not meet this security key's PIN requirements.", comment: "")

        default:
            return NSLocalizedString("The security key could not complete the request. Please try again.", comment: "")
        }
    }
}

extension CTAP2.SessionError: @retroactive LocalizedError {

    /**
     YubiKit implemented proper error descriptions almost nowhere, hence we show a
     generic message.
     */
    public var errorDescription: String? {
        return NSLocalizedString("The security key could not complete the request. Please try again.", comment: "")
    }
}
