//
//  WKScriptMessage+Extensions.swift
//  wwWallet
//
//  Created by Jens Utbult on 2024-12-06.
//

import WebKit

extension WKScriptMessage {

    static let decoder = JSONDecoder()


    var stringBody: String? {
        body as? String
    }

    var dataBody: Data? {
        stringBody?.data(using: .utf8)
    }

    /**
     If this is called during a dismissal of a view controller, it will wait until the dismissal is finished,
     so you can be pretty sure that you can then use it for presenting a new one.

     - returns: The top-most view controller which is also ready to be used for presenting a new one.
     */
    func getTopWait() async -> UIViewController? {
        await webView?.window?.rootViewController?.getTopWait()
    }


    func decode<T: Decodable>() throws -> T {
        guard let data = dataBody else {
            throw Errors.cannotDecodeMessage
        }

        return try Self.decoder.decode(T.self, from: data)
    }
}
