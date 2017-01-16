//
//  HistoryViewController.swift
//  IDSurf
//
//  Created by igor on 7/27/16.
//
//

import UIKit
import WebKit

protocol HistoryViewControllerDelegate: class {
    func didSelectUrlFromHistory(_ url:URL)
}


class HistoryViewController: UITableViewController {
    
    fileprivate let kHistoryCellID = "historyCell"
    
    var urls: [(url:URL, title: String?)] = []
    weak var delegate: HistoryViewControllerDelegate?

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.urls.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: kHistoryCellID, for: indexPath)

        let item = self.urls[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.url.absoluteString

        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = self.urls[indexPath.row]
        self.delegate?.didSelectUrlFromHistory(item.url)
        tableView.deselectRow(at: indexPath, animated: true)
        self.dismiss(animated: true, completion: nil)
    }
}
