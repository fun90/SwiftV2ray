//
//  StatusMenuController.swift
//  SwiftV2ray
//
//  Created by zc on 2017/8/3.
//  Copyright © 2017年 zc. All rights reserved.
//

import Cocoa
import Swifter

class StatusMenuController: NSObject, NSMenuDelegate {
    @IBOutlet weak var statusMenu: NSMenu!
    @IBOutlet weak var enableMenuItem: NSMenuItem!
    @IBOutlet weak var socksMenuItem: NSMenuItem!
    @IBOutlet weak var pacMenuItem: NSMenuItem!
    @IBOutlet weak var updateGfwListMenuItem: NSMenuItem!
    @IBOutlet weak var updateV2rayMenuItem: NSMenuItem!
    
    fileprivate let webServer: HttpServer = {
        let server = HttpServer()
        server["/proxy.pac"] = shareFile(kDomainPacPath)
        return server
    }()
    fileprivate lazy var proxySetting: ProxySetting = ProxySetting()
    fileprivate lazy var updater: Updater = Updater()
    
    fileprivate let getConfigKey: String = "GETV2rayConfig"
    fileprivate let postConfigKey: String = "POSTV2rayConfig"
    fileprivate let v2rayPref: String = "SwiftV2ray Preference"
    
    // MARK: - Public methods
    func launchInit() {
        log.info("Get permission to setup network.")
        proxySetting.set(.none, success: {
            self.enableService(self.enableMenuItem)
        }, failed: { error in
            if case let ProxyError.error(errMsg) = error {
                log.error(errMsg)
            }
        })
        DistributedNotificationCenter.default().addObserver(self,
                                                            selector: #selector(handleConfig(notification:)),
                                                            name: NSNotification.Name(getConfigKey),
                                                            object: v2rayPref)
        DistributedNotificationCenter.default().addObserver(self,
                                                            selector: #selector(handleConfig(notification:)),
                                                            name: NSNotification.Name(postConfigKey),
                                                            object: v2rayPref)
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
    
    // App 终止时关闭服务
    func terminate() {
        stopV2ray()
        webServer.stop()
        proxySetting.set(.none, success: {})
    }
    
    // MARK: - Actions
    
    @IBAction func enableService(_ sender: Any) {
        let isOn = enableMenuItem.state == 1
        
        // 启用的前提是 v2ray 运行中
        socksMenuItem.isEnabled = !isOn
        pacMenuItem.isEnabled = !isOn
        updateGfwListMenuItem.isEnabled = !isOn
        updateV2rayMenuItem.isEnabled = !isOn
        
        // Off
        if enableMenuItem.state == 1 {
            terminate()
            
            socksMenuItem.state = 0
            pacMenuItem.state = 0
            return
        }
        
        // On
        stopV2ray() // 防止多个执行
        startV2ray()
        
        // 默认 pac
        if case ProxyType.global(_, _, _) = proxySetting.currentType {
            socks(socksMenuItem)
        } else {
            pac(pacMenuItem)
        }
    }
    
    
    @IBAction func socks(_ sender: NSMenuItem) {
        guard sender.state != 1 else {
            return
        }
        proxySetting.set(.global(true, "localhost", kSocksPort),
                         success: {
                            sender.state = 1
                            pacMenuItem.state = 0
        })
    }
    
    @IBAction func pac(_ sender: NSMenuItem) {
        guard sender.state != 1 else {
            return
        }
        do {
            let delay = webServer.operating ? 0 : 5
            try webServer.start(in_port_t(kPacServerPort))
            // 等待同意接入网络
            DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(delay), execute: {
                self.proxySetting.set(.auto(true, "http://localhost:\(kPacServerPort)/proxy.pac"), success: {
                    sender.state = 1
                    self.socksMenuItem.state = 0
                })
            })
        } catch {
            log.error(error.localizedDescription)
        }
    }
    
    @IBAction func settings(_ sender: Any) {
        _ = try? NSWorkspace.shared().launchApplication(at: URL(fileURLWithPath: kPreferenceAppPath),
                                                        options: [.default],
                                                        configuration: [:])
    }
    
    @IBAction func updateGFWList(_ sender: NSMenuItem) {
        updater.updatePac {
            guard case ProxyType.auto(_, _) = self.proxySetting.currentType else {
                return
            }
            
            self.proxySetting.set(.none, success: {})
            self.webServer.stop()
            self.pacMenuItem.state = 0
            self.pac(self.pacMenuItem)
        }
    }
    
    @IBAction func updateV2ray(_ sender: Any) {
        updater.updateV2rayCore { (_, errMSg) in
            if let err = errMSg {
                log.error(err)
            } else if self.enableMenuItem.state == 1 {
                self.restartV2ray()
            }
        }
    }
}

extension StatusMenuController {
    fileprivate func restartV2ray() {
        stopV2ray()
        startV2ray()
    }
    
    fileprivate func startV2ray() {
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(kLaunchV2rayScript)\"")?.executeAndReturnError(&error)
        if let error = error {
            log.error(error)
        } else {
            enableMenuItem.state = 1
        }
    }
    
    fileprivate func stopV2ray() {
        var error: NSDictionary?
        NSAppleScript(source: "do shell script \"\(kKillV2rayScript)\"")?.executeAndReturnError(&error)
        if let error = error {
            log.error(error)
        } else {
            enableMenuItem.state = 0
        }
    }
}

extension StatusMenuController {
    func handleConfig(notification: NSNotification) {
        if notification.name.rawValue == getConfigKey {
            let url = URL(fileURLWithPath: kV2rayConfigurationPath)
            guard let data = try? Data(contentsOf: url) else {
                return
            }
            DistributedNotificationCenter.default().postNotificationName(Notification.Name(postConfigKey),
                                                                         object: "SwiftV2ray",
                                                                         userInfo: ["config": data],
                                                                         deliverImmediately: true)
        } else if notification.name.rawValue == postConfigKey {
            guard let configStr = notification.userInfo?["config"] as? String else{
                return
            }
            
            do {
                try configStr.write(toFile: kV2rayConfigurationPath, atomically: true, encoding: .utf8)
                if enableMenuItem.state == 1 {
                    restartV2ray()
                }
            } catch {
                log.error(error)
            }
        }
    }
}
