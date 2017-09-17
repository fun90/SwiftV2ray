//
//  ProxySetting.swift
//  SwiftV2ray
//
//  Created by zc on 2017/8/1.
//  Copyright © 2017年 zc. All rights reserved.
//

import Foundation
import Security
import SystemConfiguration

enum ProxyType {
    case global(Bool, String, Int)
    case auto(Bool, String)
    case none
    
    var enabled: Bool {
        switch self {
        case let .global(enable, _, _):
            return enable
        case let .auto(enable, _):
            return enable
        default:
            return false
        }
    }
}

enum ProxyError: Error {
    case error(String)
}

class ProxySetting {
    private(set) var currentType: ProxyType = .none
    private var authRef: AuthorizationRef?
    private var lastSettings: [String: Any]?
    
    // MARK: Private methods
    func set(_ type: ProxyType, success:() -> Void, failed:((ProxyError) -> Void)? = nil) {
        do {
            try setProxy(type: type)
            currentType = type
            success()
        } catch {
            if let failed = failed {
                failed(error as! ProxyError)
            }
        }
    }
    
    // MARK: Private methods
    private func auth(_ authRefPointer: UnsafeMutablePointer<AuthorizationRef?>) throws {
        guard authRefPointer.pointee == nil else {
            return
        }
        let authFlags: AuthorizationFlags = [.interactionAllowed, .extendRights, .preAuthorize]
        let status = AuthorizationCreate(nil, nil, authFlags, authRefPointer)
        guard status == errAuthorizationSuccess else {
            throw ProxyError.error("AuthorizationCreate failed.")
        }
    }
    
    private func setProxy(type: ProxyType) throws {
        try auth(&authRef)
        guard let myAuthRef = authRef else {
            return
        }
        
        let preference = SCPreferencesCreateWithAuthorization(nil, kAppIdentifier as CFString, nil, myAuthRef)!
        
        // https://developer.apple.com/library/content/documentation/Networking/Conceptual/SystemConfigFrameworks/SC_UnderstandSchema/SC_UnderstandSchema.html#//apple_ref/doc/uid/TP40001065-CH203-CHDFBDCB
        
        let dynamicStore = SCDynamicStoreCreate(nil, kAppIdentifier as CFString, nil, nil)
        let primaryService = SCDynamicStoreCopyValue(dynamicStore, "State:/Network/Global/IPv4" as CFString)?.value(forKey: kSCDynamicStorePropNetPrimaryService as String)
        guard let primaryServiceName = primaryService as? String else {
            throw ProxyError.error("SCDynamicStoreCopyValue failed")
        }

        if lastSettings == nil {
            let settings = SCPreferencesGetValue(preference, kSCPrefNetworkServices) as? [String: [String: Any]]
            let interfaceService = settings?[primaryServiceName]
            lastSettings = interfaceService?[kSCEntNetProxies as String] as? [String: Any]
        }
        
        // Disable all proxies
        var newProxies: [String: Any] = [kCFNetworkProxiesExceptionsList as String : ["0.0.0.0/8",
                                                                                      "10.0.0.0/8",
                                                                                      "100.64.0.0/10",
                                                                                      "127.0.0.0/8",
                                                                                      "169.254.0.0/16",
                                                                                      "172.16.0.0/12",
                                                                                      "192.0.0.0/24",
                                                                                      "192.0.2.0/24",
                                                                                      "192.100.1.0/24",
                                                                                      "192.168.0.0/16",
                                                                                      "198.18.0.0/15",
                                                                                      "198.51.100.0/24",
                                                                                      "203.0.113.0/24",
                                                                                      "::1/128",
                                                                                      "fc00::/7",
                                                                                      "fe80::/10"]]
        
        // 不能用 Bool 代替 Int，否则即使 UI 上显示已启用 proxy 仍然无法使用
        switch type {
        case let .global(enabled, proxy, port):
            newProxies[kCFNetworkProxiesSOCKSEnable as String] = enabled ? 1 : 0
            newProxies[kCFNetworkProxiesSOCKSProxy as String] = proxy
            newProxies[kCFNetworkProxiesSOCKSPort as String] = port
        case let .auto(enabled, pacUrl):
            newProxies[kCFNetworkProxiesProxyAutoConfigEnable as String] = enabled ? 1 : 0
            newProxies[kCFNetworkProxiesProxyAutoConfigURLString as String] = pacUrl
        default:
            newProxies = lastSettings ?? [:]
        }
        
        let key = "/\(kSCPrefNetworkServices as String)" +
            "/\(primaryServiceName)" +
            "/\(kSCEntNetProxies as CFString)" as CFString
        
        var trueSet: Set<Bool> = []
        trueSet.insert(SCPreferencesLock(preference, true))
        
        trueSet.insert(SCPreferencesPathSetValue(preference,
                                                 key,
                                                 newProxies as CFDictionary))
        trueSet.insert(SCPreferencesCommitChanges(preference))
        trueSet.insert(SCPreferencesApplyChanges(preference))
        SCPreferencesSynchronize(preference)
        
        trueSet.insert(SCPreferencesUnlock(preference))
        
        guard trueSet.count == 1 else {
            throw ProxyError.error("SCPreferences Lock | PathSetValue | CommitChanges | ApplyChanges | Unlock failed.")
        }
    }
}
