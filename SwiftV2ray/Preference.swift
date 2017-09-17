//
//  Preference.swift
//  SwiftV2ray
//
//  Created by zc on 2017/9/17.
//  Copyright © 2017年 zc. All rights reserved.
//

import Foundation

class Preference {
    static let `default` = Preference()
    private let versionKey = "v2rayVersion"
    
    var v2rayVersion: String = "" {
        didSet {
            plist?.setValue(v2rayVersion, forKey: versionKey)
            save()
        }
    }
    var socksPort: Int = 1080
    var socksAddress: String = "127.0.0.1"
    private var plist: NSDictionary?
    
    private init() {
        plist = NSDictionary(contentsOfFile: kPreferencePath)
        v2rayVersion = plist?.value(forKey: versionKey) as? String ?? kPreferencePath
        self.readConfig()
    }
    
    func save() {
        plist?.write(toFile: kPreferencePath, atomically: true)
    }
    
    private func readConfig() {
        guard let confiStr = try? String(contentsOfFile: kV2rayConfigurationPath) else {
            log.error("Read config.json failed.")
            return
        }
        
        guard let re = try? NSRegularExpression(pattern: "//.*$|/\\*(.|\n)*?\\*/", options: [.caseInsensitive, .anchorsMatchLines]) else {
            log.error("Regular expression init failed for deleting comments.")
            return
        }
        let pureJson = re.stringByReplacingMatches(in: confiStr, options: NSRegularExpression.MatchingOptions(rawValue: 0), range: NSMakeRange(0, confiStr.characters.count), withTemplate: "")
        
        guard let data = pureJson.data(using: .utf8),
            let dic = (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)) as? [String: Any] else {
                log.error("Pure json to dictionary failed")
                return
        }
        guard let inbound = dic["inbound"] as? [String: Any],
            let inProtocol = inbound["protocol"] as? String,
            inProtocol == "socks" else {
                log.error("inbound has no socks protocol.")
                return
        }
        
        socksPort = (inbound["port"] as? Int) ?? socksPort
        socksAddress = (inbound["listen"] as? String) ?? socksAddress
    }
}
