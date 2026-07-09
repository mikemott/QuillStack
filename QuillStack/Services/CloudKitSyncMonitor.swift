import Foundation
import CoreData
import os

/// SwiftData mirrors to CloudKit through `NSPersistentCloudKitContainer`, which
/// posts every setup / import / export event — including the error that caused a
/// failure — on the default NotificationCenter. Nothing observed it, so CloudKit
/// failures were completely invisible: the app looked healthy while syncing
/// nothing. This is the same silent-failure pattern as the `catch` that
/// downgraded the container to local-only.
@MainActor
@Observable
final class CloudKitSyncMonitor {

    static let shared = CloudKitSyncMonitor()

    struct Status: Sendable, Equatable {
        var eventType: String
        var succeeded: Bool
        var date: Date
        /// On-device display only. Never transmitted — may embed identifiers.
        var errorDescription: String?
        /// CKError.partialFailure hides the real cause in partialErrorsByItemID,
        /// which localizedDescription discards. Keep the underlying detail.
        var errorDetail: String?
    }

    private(set) var lastStatus: Status?
    private(set) var lastFailure: Status?

    private var observer: NSObjectProtocol?
    private let logger = Logger(subsystem: "com.quillstack", category: "CloudKitSync")

    private init() {}

    func start() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { note in
            guard
                let event = note.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey]
                    as? NSPersistentCloudKitContainer.Event,
                event.endDate != nil          // only completed events
            else { return }

            let status = Status(
                eventType: Self.name(for: event.type),
                succeeded: event.succeeded,
                date: event.endDate ?? .now,
                errorDescription: event.error?.localizedDescription,
                errorDetail: event.error.map { Self.detail(for: $0) }
            )

            // addObserver(queue: .main) guarantees main-thread delivery.
            MainActor.assumeIsolated {
                Self.shared.record(status)
            }
        }
    }

    private func record(_ status: Status) {
        lastStatus = status
        if !status.succeeded {
            lastFailure = status
            logger.error("CloudKit \(status.eventType) failed: \(status.errorDescription ?? "unknown")")
        } else {
            logger.info("CloudKit \(status.eventType) succeeded")
        }

        #if DEBUG
        // os_log cannot be read from an attached device without root; stdout can
        // (`devicectl device process launch --console`). Debug builds only.
        print("[CloudKitSync] \(status.eventType) succeeded=\(status.succeeded) error=\(status.errorDescription ?? "none")")
        if let detail = status.errorDetail {
            print("[CloudKitSync] detail: \(detail)")
        }
        #endif
    }

    /// A CKError.partialFailure can carry the per-zone cause in userInfo, so walk
    /// it and recurse into nested NSErrors rather than relying on
    /// localizedDescription, which discards them.
    ///
    /// Note: for the `setup` event the error arrives with an empty userInfo
    /// (`CKErrorDomain code=2 "(null)"`). The detailed per-zone reason is only
    /// emitted to CoreData's os_log, not through this notification.
    nonisolated private static func detail(for error: Error, depth: Int = 0) -> String {
        let ns = error as NSError
        let pad = String(repeating: "  ", count: depth)
        var out = "\(pad)\(ns.domain) code=\(ns.code)"

        guard depth < 3 else { return out }

        for (key, value) in ns.userInfo {
            if let nested = value as? NSError {
                out += "\n\(pad)  [\(key)] →\n" + detail(for: nested, depth: depth + 2)
            } else if let dict = value as? [AnyHashable: Any] {
                for (innerKey, innerValue) in dict {
                    if let nested = innerValue as? NSError {
                        out += "\n\(pad)  [\(key)/\(innerKey)] →\n" + detail(for: nested, depth: depth + 2)
                    }
                }
            } else if key == "ServerErrorDescription" || key == NSLocalizedFailureReasonErrorKey {
                out += "\n\(pad)  \(key)=\(value)"
            }
        }
        return out
    }

    nonisolated private static func name(for type: NSPersistentCloudKitContainer.EventType) -> String {
        switch type {
        case .setup: "setup"
        case .import: "import"
        case .export: "export"
        @unknown default: "unknown"
        }
    }
}
