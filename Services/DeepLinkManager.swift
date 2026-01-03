//
//  DeepLinkManager.swift
//  QuillStack
//
//  Created on 2026-01-02.
//

import Foundation
import SwiftUI

enum DeepLink: Equatable {
    case captureCamera
    case captureVoice
    case note(UUID)
    case tab(Int)

    init?(url: URL) {
        guard url.scheme == "quillstack" else { return nil }

        let host = url.host() ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "capture":
            if let mode = pathComponents.first {
                switch mode {
                case "camera":
                    self = .captureCamera
                case "voice":
                    self = .captureVoice
                default:
                    return nil
                }
            } else {
                // Default to camera if no mode specified
                self = .captureCamera
            }

        case "note":
            if let uuidString = pathComponents.first,
               let uuid = UUID(uuidString: uuidString) {
                self = .note(uuid)
            } else {
                return nil
            }

        case "tab":
            if let indexString = pathComponents.first,
               let index = Int(indexString) {
                self = .tab(index)
            } else {
                return nil
            }

        default:
            return nil
        }
    }
}

@MainActor
@Observable
class DeepLinkManager {
    var activeDeepLink: DeepLink?

    func handle(url: URL) {
        print("🔗 Handling deep link: \(url)")

        guard let deepLink = DeepLink(url: url) else {
            print("❌ Invalid deep link URL: \(url)")
            return
        }

        print("✅ Parsed deep link: \(deepLink)")
        activeDeepLink = deepLink
    }

    func reset() {
        activeDeepLink = nil
    }
}
