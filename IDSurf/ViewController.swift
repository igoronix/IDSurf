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

class ViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UISearchBarDelegate {
    
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var progressView: UIProgressView!
    @IBOutlet weak var toolBar: UIToolbar!
    
    var webView : WKWebView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.webView = WKWebView(frame: self.containerView.bounds, configuration: WKWebViewConfiguration())
        self.webView.UIDelegate = self
        self.webView.navigationDelegate = self
        self.containerView.addSubview(self.webView)
        
        let url = NSURL(string: "https://google.com/")
        let request = NSURLRequest(URL: url!)
        
        self.webView.loadRequest(request)
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.addObserver(self, forKeyPath: NSStringFromSelector(Selector("estimatedProgress")), options:.New, context: &IDSurfContext)
    }
    
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
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    deinit {
        self.webView?.UIDelegate = nil
        self.webView?.navigationDelegate
        self.webView!.stopLoading()
        
        if self.isViewLoaded() {
            self.webView.removeObserver(self, forKeyPath: NSStringFromSelector(Selector("estimatedProgress")))
        }
    }
    
    //MARK:- UISearchBarDelegate
    
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        self.searchBar.resignFirstResponder()
        let text = self.searchBar.text
        
        var url:NSURL? = NSURL(string: text!)
        if url == nil {
            let escapedPath = text!.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLHostAllowedCharacterSet())
            url = NSURL(string: "https://www.google.com/?#q=\(escapedPath!)")
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
        print(error.localizedDescription)
    }
    func webView(webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        print("Start to load")
    }
    func webView(webView: WKWebView, didFinishNavigation navigation: WKNavigation!) {
        print("Finish to load")
    }
    
    //MARK:- Private
    
    func validateUrl(urlString: String?) -> Bool {
        let urlRegEx = "(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+"
        return NSPredicate(format: "SELF MATCHES %@", urlRegEx).evaluateWithObject(urlString)
    }
}
