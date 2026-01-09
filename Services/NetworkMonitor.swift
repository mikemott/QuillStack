//
//  NetworkMonitor.swift
//  QuillStack
//
//  Created on 2026-01-09.
//

import Foundation
import Network
import Observation

/// Monitors network connectivity status and notifies observers of changes
@Observable
@MainActor
final class NetworkMonitor {
    /// Shared instance for app-wide access
    static let shared = NetworkMonitor()

    /// Current connectivity status
    private(set) var isConnected: Bool = true

    /// The underlying network path monitor
    private let monitor: NWPathMonitor

    /// Queue for network monitoring callbacks
    private let queue = DispatchQueue(label: "com.quillstack.networkmonitor")

    /// Notification posted when connectivity changes
    static let connectivityDidChange = Notification.Name("NetworkMonitorConnectivityDidChange")

    private init() {
        monitor = NWPathMonitor()
        setupMonitoring()
    }

    /// Start monitoring network connectivity
    private func setupMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                let wasConnected = self.isConnected
                self.isConnected = path.status == .satisfied

                // Only notify if status changed
                if wasConnected != self.isConnected {
                    NotificationCenter.default.post(
                        name: Self.connectivityDidChange,
                        object: self,
                        userInfo: ["isConnected": self.isConnected]
                    )
                }
            }
        }

        monitor.start(queue: queue)
    }

    /// Stop monitoring (for cleanup if needed)
    func stopMonitoring() {
        monitor.cancel()
    }

    deinit {
        monitor.cancel()
    }
}
