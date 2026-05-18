//
//  UserSelectionViewController.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 18.05.26.
//

import UIKit
import YubiKit

class UserSelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var users = [WebAuthn.User]()

    var resultCallback: ((_ user: WebAuthn.User?) -> Void)? = nil


    convenience init() {
        self.init(nibName: String(describing: Self.self), bundle: nil)
    }


    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = NSLocalizedString("Select Identity to Use", comment: "")

        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancel))
    }


    // MARK: UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        users.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: nil)
        cell.textLabel?.text = users[indexPath.row].fallbackName
        cell.detailTextLabel?.text = users[indexPath.row].id.base64EncodedString()

        return cell
    }


    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dismiss(animated: true)

        resultCallback?(users[indexPath.row])
    }


    // MARK: Actions

    @objc
    func cancel() {
        dismiss(animated: true)

        resultCallback?(nil)
    }
}
