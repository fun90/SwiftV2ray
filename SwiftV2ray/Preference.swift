//
//  Preference.swift
//  SwiftV2ray
//
//  Created by zc on 2017/9/17.
//  Copyright © 2017年 zc. All rights reserved.
//

import Foundation

class Preference: NSObject {
    static let `default` = Preference()
    private let versionKey = "v2rayVersion"
    
    var v2rayVersion: String = "" {
        didSet {
            plist?.setValue(v2rayVersion, forKey: versionKey)
            save()
        }
    }
    private var plist: NSDictionary?
    
    private override init() {
        plist = NSDictionary(contentsOfFile: kPreferencePath)
        
        v2rayVersion = plist?.value(forKey: versionKey) as? String ?? kPreferencePath
    }
    
    func save() {
        plist?.write(toFile: kPreferencePath, atomically: true)
    }
}
