//
//  AppConstants.swift
//  SwiftV2ray
//
//  Created by zc on 2017/8/3.
//  Copyright © 2017年 zc. All rights reserved.
//

import Foundation

let kLogPath: String = { FileManager.default.homeDirectoryForCurrentUser.path + "/"}()

let kAppIdentifier: String = {
    Bundle.main.infoDictionary?[kCFBundleIdentifierKey as String] as! String
}()

let kV2rayBinaryPath: String = {
    Bundle.main.path(forResource: "v2ray", ofType: nil)!
}()

let kV2rayConfigurationPath: String = {
    Bundle.main.path(forResource: "config", ofType: "json")!
}()

let kDomainPacPath: String = {
    Bundle.main.path(forResource: "domain", ofType: "pac")!
}()

let kPacMasterPath: String = {
    Bundle.main.path(forResource: "pac-master", ofType: "pac")!
}()

let kPreferenceAppPath: String = {
    Bundle.main.path(forResource: "SwiftV2ray Preference", ofType: "app")!
}()

let kPreferencePath: String = {
    Bundle.main.path(forResource: "Preference", ofType: "plist")!
}()

let kPacServerPort = 8080

let kKillV2rayScript = "ps -ef | grep v2ray | grep -v grep | awk '{print $2}' | xargs kill"
// 不用 nohup 会阻塞主线程
let kLaunchV2rayScript = "nohup \(kV2rayBinaryPath) -config \(kV2rayConfigurationPath) > /dev/null 2>&1 &"

let kGFWListUrl = URL(string: "https://raw.githubusercontent.com/gfwlist/gfwlist/master/gfwlist.txt")!

let kV2rayReleaseUrl = URL(string: "https://api.github.com/repos/v2ray/v2ray-core/releases/latest")!



