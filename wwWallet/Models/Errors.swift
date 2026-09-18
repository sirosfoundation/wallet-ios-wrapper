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
    case proximityUnavailable
    case multipleCredentials(_ responses: [CTAP2.GetAssertion.Response])
    case faceTecNotAvailable
    case faceTecNotConfigured
    case faceTecNoPresenter
    case faceTecCancelled
    case faceTecNoCredentialOffer
    case faceTecInitializationFailed

    var localizedDescription: String {
        switch self {
        case .cannotDecodeMessage:
            return NSLocalizedString("Cannot decode message.", comment: "")

        case .cannotCreateClientDataHash:
            return NSLocalizedString("Cannot create clientDataHash", comment: "")

        case .cannotCreateUserEntity:
            return NSLocalizedString("Cannot create user entity", comment: "")

        case .error0x19:
            return "0x19"

        case .proximityUnavailable:
            return NSLocalizedString("Proximity presentation is not available.", comment: "")

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
        }
    }
}
