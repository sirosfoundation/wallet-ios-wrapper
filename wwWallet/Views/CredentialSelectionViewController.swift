//
//  CredentialSelectionViewController.swift
//  wwWallet
//
//  Created by Benjamin Erhart on 18.05.26.
//

import UIKit
import YubiKit

class CredentialSelectionViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var responses = [CTAP2.GetAssertion.Response]()

    var resultCallback: ((_ user: WebAuthn.CredentialDescriptor?) -> Void)? = nil


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
        responses.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: nil)
        cell.textLabel?.text = responses[indexPath.row].user?.fallbackName

        return cell
    }


    // MARK: UITableViewDelegate

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        dismiss(animated: true)

        resultCallback?(responses[indexPath.row].credential)
    }


    // MARK: Actions

    @objc
    func cancel() {
        dismiss(animated: true)

        resultCallback?(nil)
    }
}
