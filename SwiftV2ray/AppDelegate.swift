//
//  AppDelegate.swift
//  SwiftV2ray
//
//  Created by zc on 2017/5/4.
//  Copyright © 2017年 zc. All rights reserved.
//

import Cocoa
import XCGLogger

#if DEBUG
let log = XCGLogger.default
#else
let log = XCGLogger(identifier: "SwiftV2ray", includeDefaultDestinations: false)
#endif

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    
    let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    @IBOutlet weak var menuController: StatusMenuController!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        #if DEBUG
            log.setup(level: .debug, showThreadName: true, showLevel: true, showFileNames: true, showLineNumbers: true, fileLevel: .verbose)
        #else
            let path = FileManager.default.homeDirectoryForCurrentUser.path + "/Documents/Logs/SwiftV2ray.log"
            let destination = AutoRotatingFileDestination(writeToFile: path, shouldAppend: true)
            destination.targetMaxLogFiles = 0
            destination.targetMaxFileSize = 1024*1024*10 // 10M
            destination.logQueue = DispatchQueue.global(qos: .background)
            log.add(destination: destination)
            log.setup(level: .info, showThreadName: true, showLevel: true, showFileNames: true, showLineNumbers: true, fileLevel: .info)
        #endif
        
        //statusItem.button?.title = "X"
        statusItem.menu = menuController.statusMenu
        menuController.statusItem = statusItem
        menuController.launchInit()
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        menuController.terminate()
    }
}

