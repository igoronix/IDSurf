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
    func didSelectUrlFromHistory(url:NSURL)
}


class HistoryViewController: UITableViewController {
    
    private let kHistoryCellID = "historyCell"
    
    var urls: [(url:NSURL, title: String?)] = []
    weak var delegate: HistoryViewControllerDelegate?

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.urls.count
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(kHistoryCellID, forIndexPath: indexPath)

        let item = self.urls[indexPath.row]
        cell.textLabel?.text = item.title
        cell.detailTextLabel?.text = item.url.absoluteString

        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let item = self.urls[indexPath.row]
        self.delegate?.didSelectUrlFromHistory(item.url)
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}
