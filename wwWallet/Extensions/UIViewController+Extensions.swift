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
}
