//
//  PlatformVPNLog.swift
//  PIALibrary
//
//  Created by Davide De Rosa on 12/14/17.
//  Copyright © 2020 Private Internet Access, Inc.
//
//  This file is part of the Private Internet Access iOS Client.
//
//  The Private Internet Access iOS Client is free software: you can redistribute it and/or
//  modify it under the terms of the GNU General Public License as published by the Free
//  Software Foundation, either version 3 of the License, or (at your option) any later version.
//
//  The Private Internet Access iOS Client is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
//  or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
//  details.
//
//  You should have received a copy of the GNU General Public License along with the Private
//  Internet Access iOS Client.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
#if os(iOS)
import UIKit
#else
import Cocoa
#endif
import __PIALibraryNative

class PlatformVPNLog: DebugLog {
    private static let alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

    let identifier: String
    
    let content: String
    
    var isEmpty: Bool {
        return content.isEmpty
    }
    
    let target: LogTarget? = {
        #if os(iOS)
            let appVersion = Macros.versionFullString() ?? "unknown"
            let device = UIDevice.current
            let osVersion = "\(device.systemName) \(device.systemVersion)"
            let deviceType = UIDevice.current.model

            return LogTarget(
                appVersion: appVersion,
                osVersion: osVersion,
                deviceType: deviceType
            )
        #else
            // TODO: details about macOS device in debug log
            return nil
        #endif
    }()
    
    init(rawContent: String) {
        let hex = arc4random() % (1 + 0xfffff)
        identifier = String(format: "%05X", hex)
        if !rawContent.isEmpty {
            content = PlatformVPNLog.extendedContent(from: rawContent, target: target)
        } else {
            content = rawContent
        }
    }

    private static func extendedContent(from content: String, target: LogTarget?) -> String {
        var text = ""//(capacity: 1000 + content.count)

        if let target = target {
            let sysinfo = [
                "app_version": target.appVersion,
                "device": target.deviceType,
                "os_version": target.osVersion
            ]
            if let sysinfoData = try? JSONSerialization.data(withJSONObject: sysinfo, options: []) {
                text += "sysinfo\n"
                text += String(data: sysinfoData, encoding: .ascii)!
            }
        }

        text += "\npia_log\n"
        text += content

        return text
    }

    func serialized() -> Data {
        let idPrefix = "debug_id\n\(identifier)"

        // rand % 2^256 in base 36 ~ 50 digits
        var separator = ""
        for _ in 0..<50 {
            let alphabet = PlatformVPNLog.alphabet
            let offset = UInt(arc4random()) % UInt(alphabet.count)
            let ch = alphabet[alphabet.index(alphabet.startIndex, offsetBy: Int(offset))]
            separator.append(ch)
        }
        separator.append("\n")

        let separatorBytes = separator.data(using: .utf8)!
        let idPrefixBytes = idPrefix.data(using: .utf8)!
        let contentBytes = content.data(using: .utf8)!

        var serialized = Data(capacity: 1000 + content.count + separator.count)
        serialized += separatorBytes
        serialized += (idPrefixBytes as NSData).deflated()
        serialized += separatorBytes
        serialized += (contentBytes as NSData).deflated()
        return serialized
    }
}
