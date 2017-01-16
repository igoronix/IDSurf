//
//  ViewController.swift
//  IDSurf
//
//  Created by igor on 7/26/16.
//
//

import UIKit
import WebKit

private var IDSurfContext = 0

class BrowserViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UISearchBarDelegate, HistoryViewControllerDelegate {
    
    private let kFirstURL = "https://google.com/"
    private let kHistoryDefaultsKey = "history"
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var toolBar: UIToolbar!
    
    @IBOutlet weak var backButton: UIBarButtonItem!
    @IBOutlet weak var forwardButton: UIBarButtonItem!
    @IBOutlet weak var historyButton: UIBarButtonItem!
    
    weak var webView : WKWebView!
    
    var visitedURL: [(url:URL, title: String?)] = []
    
    //MARK:- ViewController lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webView = WKWebView(frame: self.containerView.bounds, configuration: WKWebViewConfiguration())
        webView.uiDelegate = self
        webView.navigationDelegate = self
        self.containerView.addSubview(webView)
        self.webView = webView
        
        let url = URL(string: kFirstURL)
        let request = URLRequest(url: url!)
        
        self.webView.load(request)
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.addObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: WKWebView.estimatedProgress)), options:.new, context: &IDSurfContext)
        
        self.visitedURL = self.historyFromDefaults()
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillResignActive, object: nil, queue: OperationQueue.main, using: { [unowned self] (notification: Notification) -> (Void) in
            self.saveHistory()
            })
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.updateToolbar()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        print("didReceiveMemoryWarning")
    }
    
    deinit {
        self.webView.uiDelegate = nil
        self.webView.navigationDelegate = nil
        self.webView.stopLoading()
        
        if self.isViewLoaded {
            self.webView.removeObserver(self, forKeyPath: NSStringFromSelector(#selector(getter: WKWebView.estimatedProgress)))
        }
    }
    
    //MARK:- Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowHistorySegue" {
            let historyVC = (segue.destination as! UINavigationController).viewControllers.first as? HistoryViewController
            historyVC?.urls = self.visitedURL;
            historyVC?.delegate = self
        }
    }
    
    @IBAction func unwindToBrowser(_ sender: UIStoryboardSegue) {
    }
    
    //MARK:- UIBarButtonItem actions
    
    @IBAction func back(_ sender: AnyObject) {
        self.webView.goBack()
        self.updateToolbar()
    }
    
    @IBAction func forward(_ sender: AnyObject) {
        self.webView.goForward()
        self.updateToolbar()
    }
    
    
    //MARK:- KVO
    
    override func observeValue(forKeyPath keyPath: String!, of object: Any!, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == NSStringFromSelector(#selector(getter: WKWebView.estimatedProgress)) && self.webView == object as? WKWebView {
            self.progressView.alpha = 1.0
            self.progressView.setProgress(Float(self.webView.estimatedProgress), animated: true)
            
            self.webView.evaluateJavaScript("document.title", completionHandler: { (result, error) in
                if let _ = error {
                    self.searchBar.text = self.webView.url?.host
                }
                else {
                    self.searchBar.text = result as? String
                }
            })
            
            if self.webView.estimatedProgress >= 1.0 {
                UIView.animate(withDuration: 0.25, animations: {
                    self.progressView.alpha = 0.0
                    }, completion: { (finished) in
                        self.progressView.setProgress(0.0, animated: false)
                })
            }
        }
    }
    
    //MARK:- HistoryViewControllerDelegate
    
    func didSelectUrlFromHistory(_ url: URL) {
        DispatchQueue.main.async { 
            let request = URLRequest(url: url)
            self.webView.load(request)
        }
    }
    
    //MARK:- UISearchBarDelegate
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
        
        Timer.scheduledTimer(timeInterval: 0.01, target: self, selector: #selector(BrowserViewController.selectSearchBarText), userInfo: nil, repeats: false)
    }
    
    func selectSearchBarText() {
        UIApplication.shared.sendAction(#selector(UIResponderStandardEditActions.selectAll(_:)), to: nil, from: nil, for: nil)
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.showsCancelButton = false
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        let text = searchBar.text
        
        var url:URL? = URL(string: text!)
        if url == nil {
            let escapedPath = text!.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlHostAllowed)
            url = URL(string: "https://google.com/?#q=\(escapedPath!)")
        }
        else {
            if !self.validateUrl(text) {
                url = URL(string: "http://\(text!)")
            }
        }
        let request = URLRequest(url: url!)
        self.webView.load(request)
    }
    
    
    //MARK:- WKNavigationDelegate
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("FailProvisionalNavigation: \(error.localizedDescription)")

//        if error.code == NSURLErrorNotConnectedToInternet {
//            
//        }
        
//        if (error.code == NSURLErrorNotConnectedToInternet){
//            webView.loadHTMLString("No connection", baseURL:  nil)
//        }

        self.updateToolbar()
    }
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.updateToolbar()
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if let url = self.webView.url {
            if !self.isAlreadyVisited(url) {
                self.visitedURL.append((url: url, title:webView.title))
            }
        }
        self.updateToolbar()
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.updateToolbar()
    }
    
    //MARK:- Private
    
    fileprivate func updateToolbar() {
        self.backButton.isEnabled = self.webView.canGoBack
        self.forwardButton.isEnabled = self.webView.canGoForward
    }
    
    fileprivate func validateUrl(_ urlString: String?) -> Bool {
        let urlRegEx = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+"
        return NSPredicate(format: "SELF MATCHES %@", urlRegEx).evaluate(with: urlString)
    }
    
    fileprivate func isAlreadyVisited(_ url: URL) -> Bool {
        return self.visitedURL.contains { (item) -> Bool in
            return item.url.absoluteString == url.absoluteString
        }
    }
    
    fileprivate func historyFromDefaults() -> [(url:URL, title: String?)] {
        let defaults = UserDefaults.standard
        let data = defaults.object(forKey: kHistoryDefaultsKey)
        var urls: [(url:URL, title: String?)] = []
        if let data = data {
            
            let urlsDictionary = NSKeyedUnarchiver.unarchiveObject(with: data as! Data) as! NSDictionary
            urlsDictionary.enumerateKeysAndObjects({ (key, object, stop) in
                urls.append((url: object as! URL, title: key as? String));
            });
        }
        return urls
    }
    
    fileprivate func saveHistory() {
        guard self.visitedURL.count > 0 else { return }
        
        let defaults = UserDefaults.standard
        let historyDict = NSMutableDictionary()
        
        for historyItem in self.visitedURL {
            let key = historyItem.title != nil ? historyItem.title! : historyItem.url.absoluteString
            historyDict.setValue(historyItem.url, forKey: key)
        }
        
        let data = NSKeyedArchiver.archivedData(withRootObject: historyDict)
        
        defaults.set(data, forKey:self.kHistoryDefaultsKey)
        defaults.synchronize()
    }
}
