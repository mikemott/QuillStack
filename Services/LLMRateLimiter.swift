//
//  LLMRateLimiter.swift
//  QuillStack
//
//  Rate limiting for LLM API calls to prevent excessive costs
//

import Foundation

/// Rate limiter for LLM API calls
@MainActor
final class LLMRateLimiter {
    static let shared = LLMRateLimiter()

    // Rate limits (configurable)
    private let maxCallsPerMinute = 10
    private let maxCallsPerHour = 100
    private let maxCallsPerDay = 500

    // Tracking
    private var callTimestamps: [Date] = []

    private init() {}

    /// Check if a new LLM call is allowed under rate limits
    func canMakeCall() -> Bool {
        let now = Date()

        // Clean up old timestamps
        cleanupOldTimestamps(before: now)

        // Check minute limit
        let minuteAgo = now.addingTimeInterval(-60)
        let callsInLastMinute = callTimestamps.filter { $0 > minuteAgo }.count
        if callsInLastMinute >= maxCallsPerMinute {
            return false
        }

        // Check hour limit
        let hourAgo = now.addingTimeInterval(-3600)
        let callsInLastHour = callTimestamps.filter { $0 > hourAgo }.count
        if callsInLastHour >= maxCallsPerHour {
            return false
        }

        // Check day limit
        let dayAgo = now.addingTimeInterval(-86400)
        let callsInLastDay = callTimestamps.filter { $0 > dayAgo }.count
        if callsInLastDay >= maxCallsPerDay {
            return false
        }

        return true
    }

    /// Record that a call was made
    func recordCall() {
        callTimestamps.append(Date())
    }

    /// Clean up timestamps older than 24 hours
    private func cleanupOldTimestamps(before: Date) {
        let dayAgo = before.addingTimeInterval(-86400)
        callTimestamps.removeAll { $0 < dayAgo }
    }

    /// Get current usage stats (for debugging/display)
    func getUsageStats() -> (minute: Int, hour: Int, day: Int) {
        let now = Date()
        cleanupOldTimestamps(before: now)

        let minuteAgo = now.addingTimeInterval(-60)
        let hourAgo = now.addingTimeInterval(-3600)
        let dayAgo = now.addingTimeInterval(-86400)

        let minute = callTimestamps.filter { $0 > minuteAgo }.count
        let hour = callTimestamps.filter { $0 > hourAgo }.count
        let day = callTimestamps.filter { $0 > dayAgo }.count

        return (minute, hour, day)
    }

    /// Reset all rate limits (for testing)
    func reset() {
        callTimestamps.removeAll()
    }
}
