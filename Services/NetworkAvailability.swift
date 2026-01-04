//
//  NetworkAvailability.swift
//  QuillStack
//
//  Network availability checking for LLM calls
//

import Foundation
import Network
import Combine

/// Simple network availability checker
@MainActor
final class NetworkAvailability {
    static let shared = NetworkAvailability()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkAvailability")
    private var isMonitoring = false

    @Published private(set) var isConnected = true

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        guard !isMonitoring else { return }

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = path.status == .satisfied
            }
        }

        monitor.start(queue: queue)
        isMonitoring = true
    }

    /// Check if network is currently available
    var isNetworkAvailable: Bool {
        isConnected
    }

    deinit {
        monitor.cancel()
    }
}
