//
//  ViewController.swift
//  SwiftV2ray Preference
//
//  Created by zc on 2017/8/3.
//  Copyright © 2017年 zc. All rights reserved.
//

import Cocoa
import JavaScriptCore
import WebKit

class ViewController: NSViewController {
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var loadingIndicator: NSProgressIndicator!
    @IBOutlet weak var webView: WKWebView!
    
    fileprivate let getConfigKey: String = "GETV2rayConfig"
    fileprivate let postConfigKey: String = "POSTV2rayConfig"
    fileprivate let v2ray: String = "SwiftV2ray"
    fileprivate let v2rayPref: String = "SwiftV2ray Preference"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let editorPath = Bundle.main.path(forResource: "editor", ofType: "html") else {
            return
        }
        let url = URL(fileURLWithPath: editorPath, isDirectory: false)
        let docUrl = URL(fileURLWithPath: url.deletingLastPathComponent().path, isDirectory: true)
        webView.loadFileURL(url, allowingReadAccessTo: docUrl)
        webView.navigationDelegate = self
        loadingIndicator.startAnimation(nil)
    }
    
    override func viewDidAppear() {
        super.viewDidAppear()
        DistributedNotificationCenter.default().addObserver(self,
                                                            selector: #selector(handleConfig(notification:)),
                                                            name: NSNotification.Name(postConfigKey),
                                                            object: v2ray)
    }
    override func viewDidDisappear() {
        super.viewDidDisappear()
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    @IBAction func toAce(_ sender: Any) {
        NSWorkspace.shared().open(URL(string: "https://ace.c9.io/")!)
    }
    @IBAction func format(_ sender: Any) {
        webView.evaluateJavaScript("beautify();", completionHandler: nil)
    }
    
    @IBAction func done(_ sender: NSButton) {
        webView.evaluateJavaScript("editor.getSession().getAnnotations();") { [weak self] (obj, _) in
            guard let annotations = obj as? [[String: Any]], annotations.count > 0 else {
                self?.submit()
                return
            }
            
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Syntax Error!"
            let rows = Set<Int>(annotations.map({ ($0["row"] as? Int ?? 0) + 1 }))
            alert.informativeText = "Error at line:\(rows). \nPlease check your config and apply."
            alert.addButton(withTitle: "Done")
            alert.beginSheetModal(for: NSApplication.shared().mainWindow!, completionHandler: nil)
        }
    }
}

extension ViewController {
    func handleConfig(notification: NSNotification) {
        guard let data = notification.userInfo?["config"] as? Data else {
            return
        }
        webView.evaluateJavaScript("decodeBase64Config(\'\(data.base64EncodedString())\');") { [weak self] (_, error) in
            self?.loadingIndicator.stopAnimation(nil)
        }
    }
    
    func submit() {
        webView.evaluateJavaScript("editor.getValue();") { [unowned self] (result, error) in
            guard let json = result as? String else {
                    return
            }
            DistributedNotificationCenter.default().postNotificationName(Notification.Name(self.postConfigKey),
                                                                         object: self.v2rayPref,
                                                                         userInfo: ["config": json],
                                                                         deliverImmediately: true)
            exit(0)
        }
    }
}

extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        DistributedNotificationCenter.default().postNotificationName(Notification.Name(getConfigKey),
                                                                     object: v2rayPref,
                                                                     userInfo: nil,
                                                                     deliverImmediately: true)
    }
}
