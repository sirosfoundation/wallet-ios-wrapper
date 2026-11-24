//
//  UIViewController+Extensions.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 10.04.25.
//

import UIKit

extension UIViewController {

    /**
     Returns the top-most view controller, which *isn't currently being dismissed.*
     */
    public var top: UIViewController {
        if let vc = subViewController, !vc.isBeingDismissed {
            return vc.top
        }

        return self
    }

    public var subViewController: UIViewController? {
        if let vc = self as? UINavigationController {
            return vc.topViewController
        }

        if let vc = self as? UISplitViewController {
            return vc.viewControllers.last
        }

        if let vc = self as? UITabBarController {
            return vc.selectedViewController
        }

        if let vc = presentedViewController {
            return vc
        }

        return nil
    }


    /**
     If this is called during a dismissal of a view controller, it will wait until the dismissal is finished,
     so you can be pretty sure that you can then use it for presenting a new one.

     - returns: The top-most view controller which is also ready to be used for presenting a new one.
     */
    public func getTopWait() async -> UIViewController {
        if let vc = subViewController {
            if vc.isBeingDismissed {
                // Wait until the dismissal of the subViewController is done.
                while subViewController != nil {
                    try? await Task.sleep(nanoseconds: UInt64(0.1 * Double(NSEC_PER_SEC)))
                }

                // Only then return ourselves, to avoid a race condition, where we
                // cannot present a new view controller because an old one is still
                // being dismissed.
                return self
            }

            return await vc.getTopWait()
        }

        return self
    }
}
