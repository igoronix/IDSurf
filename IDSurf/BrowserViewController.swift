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
    
    var visitedURL: [(url:NSURL, title: String?)] = []
    
    //MARK:- ViewController lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let webView = WKWebView(frame: self.containerView.bounds, configuration: WKWebViewConfiguration())
        webView.UIDelegate = self
        webView.navigationDelegate = self
        self.containerView.addSubview(webView)
        self.webView = webView
        
        let url = NSURL(string: kFirstURL)
        let request = NSURLRequest(URL: url!)
        
        self.webView.loadRequest(request)
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.addObserver(self, forKeyPath: NSStringFromSelector(Selector("estimatedProgress")), options:.New, context: &IDSurfContext)
        
        self.visitedURL = self.historyFromDefaults()
        
        NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillResignActiveNotification, object: nil, queue: NSOperationQueue.mainQueue(), usingBlock: { [unowned self] (notification: NSNotification) -> (Void) in
            self.saveHistory()
            })
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.updateToolbar()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        
        print("didReceiveMemoryWarning")
    }
    
    deinit {
        self.webView.UIDelegate = nil
        self.webView.navigationDelegate = nil
        self.webView.stopLoading()
        
        if self.isViewLoaded() {
            self.webView.removeObserver(self, forKeyPath: NSStringFromSelector(Selector("estimatedProgress")))
        }
    }
    
    //MARK:- Navigation
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "ShowHistorySegue" {
            let historyVC = (segue.destinationViewController as! UINavigationController).viewControllers.first as? HistoryViewController
            historyVC?.urls = self.visitedURL
            historyVC?.delegate = self
        }
    }
    
    @IBAction func unwindToBrowser(sender: UIStoryboardSegue) {
    }
    
    //MARK:- UIBarButtonItem actions
    
    @IBAction func back(sender: AnyObject) {
        self.webView.goBack()
        self.updateToolbar()
    }
    
    @IBAction func forward(sender: AnyObject) {
        self.webView.goForward()
        self.updateToolbar()
    }
    
    
    //MARK:- KVO
    
    override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        if keyPath == NSStringFromSelector(Selector("estimatedProgress")) && self.webView == object as? WKWebView {
            self.progressView.alpha = 1.0
            self.progressView.setProgress(Float(self.webView.estimatedProgress), animated: true)
            
            self.webView.evaluateJavaScript("document.title", completionHandler: { (result, error) in
                if let _ = error {
                    self.searchBar.text = self.webView.URL?.host
                }
                else {
                    self.searchBar.text = result as? String
                }
            })
            
            if self.webView.estimatedProgress >= 1.0 {
                UIView.animateWithDuration(0.25, animations: {
                    self.progressView.alpha = 0.0
                    }, completion: { (finished) in
                        self.progressView.setProgress(0.0, animated: false)
                })
            }
        }
    }
    
    //MARK:- HistoryViewControllerDelegate
    
    func didSelectUrlFromHistory(url: NSURL) {
        dispatch_async(dispatch_get_main_queue()) { 
            let request = NSURLRequest(URL: url)
            self.webView.loadRequest(request)
        }
    }
    
    //MARK:- UISearchBarDelegate
    
    func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        searchBar.showsCancelButton = true
        for view in searchBar.subviews as [UIView] {
            for subview in view.subviews as [UIView] {
                if let textField = subview as? UITextField {
                    textField.performSelector(#selector(NSObject.selectAll(_:)), withObject: nil, afterDelay: 0.0)
                }
            }
        }
    }
    
    func searchBarTextDidEndEditing(searchBar: UISearchBar) {
        searchBar.showsCancelButton = false
    }
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        
        let text = searchBar.text
        
        var url:NSURL? = NSURL(string: text!)
        if url == nil {
            let escapedPath = text!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLHostAllowedCharacterSet())
            url = NSURL(string: "https://google.com/?#q=\(escapedPath!)")
        }
        else {
            if !self.validateUrl(text) {
                url = NSURL(string: "http://\(text!)")
            }
        }
        let request = NSURLRequest(URL: url!)
        self.webView.loadRequest(request)
    }
    
    
    //MARK:- WKNavigationDelegate
    
    func webView(webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: NSError) {
        print("FailProvisionalNavigation: \(error.localizedDescription)")
        
        if (error.code == NSURLErrorNotConnectedToInternet){
            webView.loadHTMLString("No connection", baseURL:  nil)
        }

        self.updateToolbar()
    }
    
    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.updateToolbar()
    }
    
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        if let url = self.webView.URL {
            if !self.isAlreadyVisited(url) {
                self.visitedURL.append((url: url, title:webView.title))
            }
        }
        self.updateToolbar()
    }
    
    func webView(webView: WKWebView, didFailNavigation navigation: WKNavigation!, withError error: NSError) {
        self.updateToolbar()
    }
    
    //MARK:- Private
    
    private func updateToolbar() {
        self.backButton.enabled = self.webView.canGoBack
        self.forwardButton.enabled = self.webView.canGoForward
    }
    
    private func validateUrl(urlString: String?) -> Bool {
        let urlRegEx = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+"
        return NSPredicate(format: "SELF MATCHES %@", urlRegEx).evaluateWithObject(urlString)
    }
    
    private func isAlreadyVisited(url: NSURL) -> Bool {
        return self.visitedURL.contains { (item) -> Bool in
            return item.url.absoluteString == url.absoluteString
        }
    }
    
    private func historyFromDefaults() -> [(url:NSURL, title: String?)] {
        let defaults = NSUserDefaults.standardUserDefaults()
        let data = defaults.objectForKey(kHistoryDefaultsKey)
        var urls: [(url:NSURL, title: String?)] = []
        if let data = data {
            
            let urlsDictionary = NSKeyedUnarchiver.unarchiveObjectWithData(data as! NSData) as! NSDictionary
            urlsDictionary.enumerateKeysAndObjectsUsingBlock { (key, object, stop) in
                urls.append((url: object as! NSURL, title: key as? String))
            }
        }
        return urls
    }
    
    private func saveHistory() {
        guard self.visitedURL.count > 0 else { return }
        
        let defaults = NSUserDefaults.standardUserDefaults()
        let historyDict = NSMutableDictionary()
        
        for historyItem in self.visitedURL {
            let key = historyItem.title != nil ? historyItem.title! : historyItem.url.absoluteString
            historyDict.setValue(historyItem.url, forKey: key)
        }
        
        let data = NSKeyedArchiver.archivedDataWithRootObject(historyDict)
        
        defaults.setObject(data, forKey:self.kHistoryDefaultsKey)
        defaults.synchronize()
    }
}
