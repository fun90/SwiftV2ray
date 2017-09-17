//
//  GFWList2Pac.swift
//  SwiftV2ray
//
//  Created by zc on 2017/8/5.
//  Copyright © 2017年 zc. All rights reserved.
//

import Foundation

// https://github.com/itcook/gfwlist2pac

class Updater {
    fileprivate(set) var updating: Bool = false
    fileprivate lazy var session = URLSession(configuration: URLSessionConfiguration.default)
    
    func updatePac(success:@escaping () -> Void) {
        guard !updating else {
            return
        }
        log.info("Begin update gfwlist...")
        updating = true
        DispatchQueue.global().async {
            if self.fetchAndGenerate() {
                success()
                log.info("Update gfwlist success.")
            }
            self.updating = false
        }
    }
    
    private func fetchAndGenerate() -> Bool {
        let domains = self.fetchGFWList()
        guard domains.count > 0 else {
            log.error("Domains are empty.")
            return false
        }
        guard let jsonData = try? JSONSerialization.data(withJSONObject: domains, options: .prettyPrinted) else {
            log.error("JSONSerialization failed.")
            return false
        }
        guard let domainJson = String(data: jsonData, encoding: .utf8) else {
            log.error("JSON data to String failed.")
            return false
        }
        guard var pac = try? String(contentsOfFile: kPacMasterPath) else {
            log.error("Read master pac failed.")
            return false
        }
        
        let pref = Preference.default
        let socks5 = "\"SOCKS5 \(pref.socksAddress):\(pref.socksPort); SOCKS \(pref.socksAddress):\(pref.socksPort); DIRECT;\""
        pac = pac.replacingOccurrences(of: "__DOMAINS__", with: domainJson)
        pac = pac.replacingOccurrences(of: "__PROXY__", with: socks5)
        
        do {
            try pac.write(toFile: kDomainPacPath, atomically: true, encoding: .utf8)
            return true
        } catch {
            log.error("Write domain pac failed.")
            return false
        }
    }
    
    private func fetchGFWList() -> [String: Int] {
        
        func add(name: String, to domains: inout [String: Int]) {
            var domain: String = name
            if !name.hasPrefix("http") {
                domain = "http://" + domain
            }
            
            if var host = URL(string: domain)?.host {
                if host.hasPrefix(".") {
                    let index = host.index(host.startIndex, offsetBy: 1)
                    host = host.substring(from: index)
                } else if host.hasSuffix("/") {
                    let index = host.index(host.endIndex, offsetBy: -1)
                    host = host.substring(to: index)
                } else if host.hasPrefix("www.") {
                    let index = host.index(host.startIndex, offsetBy: 4)
                    host = host.substring(from: index)
                }
                domains[host] = 1
            }
        }
        
        var domains = ["raw.githubusercontent.com": 1,
                       "google.com.hk": 1]
        
        guard let base64Data = try? Data(contentsOf: kGFWListUrl),
            let decodedData = Data(base64Encoded: base64Data, options: .ignoreUnknownCharacters),
            let content = String(data: decodedData, encoding: .utf8) else {
                return domains
        }
        
        let gfwList = content.components(separatedBy: "\n")
        gfwList.forEach({ (line) in
            // ignore white list, generic domain, comment
            guard !line.contains(".*") else {
                return
            }
            
            var mutableLine = line
            if mutableLine.contains("*") {
                mutableLine = mutableLine.replacingOccurrences(of: "*", with: "/")
            }
            
            guard !line.hasPrefix("@"),
                !line.hasPrefix("["),
                !line.hasPrefix("!") else {
                    return
            }
            
            if mutableLine.hasPrefix("||") {
                let fromIndex = mutableLine.index(mutableLine.startIndex, offsetBy: 2)
                mutableLine = mutableLine.substring(from: fromIndex)
            } else if mutableLine.hasPrefix("|") {
                let fromIndex = mutableLine.index(mutableLine.startIndex, offsetBy: 1)
                mutableLine = mutableLine.substring(from: fromIndex)
            } else if mutableLine.hasPrefix(".") {
                let fromIndex = mutableLine.index(mutableLine.startIndex, offsetBy: 1)
                mutableLine = mutableLine.substring(from: fromIndex)
            }
            add(name: mutableLine, to: &domains)
        })
        
        return domains
    }
}

extension Updater {
    func updateV2rayCore(_ result: @escaping (Bool, String?) -> Void) {
        guard !updating else {
            return
        }
        updating = true
        log.info("Begin update v2ray core.")
        latestV2rayVersion { (success, version) in
            guard success else {
                result(success, version)
                return
            }
            
            guard version != Preference.default.v2rayVersion else {
                result(false, "Lastest version \(version) is already installed")
                self.updating = false
                return
            }
            self.downloadV2ray(version, result: { (success, errMsg) in
                result(success, errMsg)
                if success {
                    log.info("Update v2ray core success.")
                    Preference.default.v2rayVersion = version
                }
                self.updating = false
            })
        }
    }
    
    private func latestV2rayVersion(_ result: @escaping (Bool, String) -> Void) {
        DispatchQueue.global().async {
            guard let data = try? Data(contentsOf: kV2rayReleaseUrl),
                let jsonDic = (try? JSONSerialization.jsonObject(with: data, options: .allowFragments)) as? [String: Any],
                let version = jsonDic["tag_name"] as? String else {
                    result(false, "Check latest version failed.")
                    return
            }
            result(true, version)
        }
    }
    
    private func downloadV2ray(_ version: String, result: @escaping (Bool, String?) -> Void) {
        let url = URL(string: "https://github.com/v2ray/v2ray-core/releases/download/\(version)/v2ray-macos.zip")!
        session.downloadTask(with: URLRequest(url: url)) { (tempUrl, _, error) in
            guard error == nil, let fromPath = tempUrl?.path else {
                result(false, error != nil ? error!.localizedDescription : "V2ray downloading has no destination path.")
                return
            }
            let tempDirectory = Bundle.main.resourcePath!
            do {
                let tempZipPath = tempDirectory + "/v2ray-macos.zip"
                let tempV2ray = tempDirectory + "/TempV2ray"
                try FileManager.default.moveItem(atPath: fromPath, toPath: tempZipPath)
                let shellScript = "mkdir \(tempV2ray) && unzip \(tempZipPath) -d \(tempV2ray) && cp \(tempV2ray + "/v2ray-\(version)-macos/v2ray") \(kV2rayBinaryPath) && rm -rf \(tempV2ray) \(tempZipPath)"
                
                var error: NSDictionary?
                NSAppleScript(source: "do shell script \"\(shellScript)\"")?.executeAndReturnError(&error)
                
                if let error = error {
                    result(false, error.description)
                } else {
                    result(true, nil)
                }
            } catch {
                result(false, error.localizedDescription)
            }
            
        }.resume()
    }
}
