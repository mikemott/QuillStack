//
//  LLMRateLimiter.swift
//  QuillStack
//
//  Rate limiting for LLM API calls to prevent excessive costs
//

import Foundation

/// Rate limiter for LLM API calls to prevent excessive costs
/// Tracks calls per minute, hour, and day with user-configurable limits
/// Falls back to heuristic classification when limits are exceeded
@MainActor
final class LLMRateLimiter {
    static let shared = LLMRateLimiter()

    private let defaults = UserDefaults.standard

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let callsThisMinute = "llm_calls_this_minute"
        static let callsThisHour = "llm_calls_this_hour"
        static let callsThisDay = "llm_calls_this_day"
        static let lastCallTimestamp = "llm_last_call_timestamp"
        static let lastMinuteReset = "llm_last_minute_reset"
        static let lastHourReset = "llm_last_hour_reset"
        static let lastDayReset = "llm_last_day_reset"

        // User-configurable limits
        static let maxCallsPerMinute = "llm_max_calls_per_minute"
        static let maxCallsPerHour = "llm_max_calls_per_hour"
        static let maxCallsPerDay = "llm_max_calls_per_day"
    }

    // MARK: - Default Limits

    /// Default rate limits designed to prevent excessive costs while allowing normal usage
    /// These are conservative limits - 5 calls/minute prevents rapid-fire requests
    /// Estimated cost at default limits: ~$2-4 per day maximum
    private struct DefaultLimits {
        static let perMinute = 5      // Max 5 calls per minute
        static let perHour = 50       // Max 50 calls per hour (~$0.50-1.00 depending on usage)
        static let perDay = 200       // Max 200 calls per day (~$2-4 per day max)
    }

    // MARK: - Configuration

    var maxCallsPerMinute: Int {
        get {
            let value = defaults.integer(forKey: Keys.maxCallsPerMinute)
            return value > 0 ? value : DefaultLimits.perMinute
        }
        set {
            defaults.set(newValue, forKey: Keys.maxCallsPerMinute)
        }
    }

    var maxCallsPerHour: Int {
        get {
            let value = defaults.integer(forKey: Keys.maxCallsPerHour)
            return value > 0 ? value : DefaultLimits.perHour
        }
        set {
            defaults.set(newValue, forKey: Keys.maxCallsPerHour)
        }
    }

    var maxCallsPerDay: Int {
        get {
            let value = defaults.integer(forKey: Keys.maxCallsPerDay)
            return value > 0 ? value : DefaultLimits.perDay
        }
        set {
            defaults.set(newValue, forKey: Keys.maxCallsPerDay)
        }
    }

    // MARK: - Call Tracking

    /// Check if a new LLM call can be made within rate limits
    /// Returns false if any time window limit is exceeded
    func canMakeCall() -> Bool {
        let now = Date()

        // Reset counters if time windows have passed
        resetExpiredWindows(currentTime: now)

        // Check all time windows
        let callsThisMinute = defaults.integer(forKey: Keys.callsThisMinute)
        let callsThisHour = defaults.integer(forKey: Keys.callsThisHour)
        let callsThisDay = defaults.integer(forKey: Keys.callsThisDay)

        // Allow call only if all limits are satisfied
        return callsThisMinute < maxCallsPerMinute &&
               callsThisHour < maxCallsPerHour &&
               callsThisDay < maxCallsPerDay
    }

    /// Record a successful LLM API call
    /// Updates all time window counters
    func recordCall() {
        let now = Date()

        // Reset expired windows before recording
        resetExpiredWindows(currentTime: now)

        // Increment counters for all time windows
        let callsThisMinute = defaults.integer(forKey: Keys.callsThisMinute)
        let callsThisHour = defaults.integer(forKey: Keys.callsThisHour)
        let callsThisDay = defaults.integer(forKey: Keys.callsThisDay)

        defaults.set(callsThisMinute + 1, forKey: Keys.callsThisMinute)
        defaults.set(callsThisHour + 1, forKey: Keys.callsThisHour)
        defaults.set(callsThisDay + 1, forKey: Keys.callsThisDay)
        defaults.set(now.timeIntervalSince1970, forKey: Keys.lastCallTimestamp)
    }

    /// Reset counters for expired time windows
    private func resetExpiredWindows(currentTime: Date) {
        let currentTimestamp = currentTime.timeIntervalSince1970

        // Minute window
        let lastMinuteReset = defaults.double(forKey: Keys.lastMinuteReset)
        if currentTimestamp - lastMinuteReset >= 60 {
            defaults.set(0, forKey: Keys.callsThisMinute)
            defaults.set(currentTimestamp, forKey: Keys.lastMinuteReset)
        }

        // Hour window
        let lastHourReset = defaults.double(forKey: Keys.lastHourReset)
        if currentTimestamp - lastHourReset >= 3600 {
            defaults.set(0, forKey: Keys.callsThisHour)
            defaults.set(currentTimestamp, forKey: Keys.lastHourReset)
        }

        // Day window
        let lastDayReset = defaults.double(forKey: Keys.lastDayReset)
        if currentTimestamp - lastDayReset >= 86400 {
            defaults.set(0, forKey: Keys.callsThisDay)
            defaults.set(currentTimestamp, forKey: Keys.lastDayReset)
        }
    }

    // MARK: - Status Information

    /// Get current usage statistics for display in Settings
    func getCurrentUsage() -> RateLimitUsage {
        let now = Date()
        resetExpiredWindows(currentTime: now)

        let callsThisMinute = defaults.integer(forKey: Keys.callsThisMinute)
        let callsThisHour = defaults.integer(forKey: Keys.callsThisHour)
        let callsThisDay = defaults.integer(forKey: Keys.callsThisDay)

        return RateLimitUsage(
            callsThisMinute: callsThisMinute,
            callsThisHour: callsThisHour,
            callsThisDay: callsThisDay,
            maxPerMinute: maxCallsPerMinute,
            maxPerHour: maxCallsPerHour,
            maxPerDay: maxCallsPerDay
        )
    }

    /// Reset all rate limit counters (for testing or user-requested reset)
    func resetAllLimits() {
        defaults.set(0, forKey: Keys.callsThisMinute)
        defaults.set(0, forKey: Keys.callsThisHour)
        defaults.set(0, forKey: Keys.callsThisDay)

        let now = Date().timeIntervalSince1970
        defaults.set(now, forKey: Keys.lastMinuteReset)
        defaults.set(now, forKey: Keys.lastHourReset)
        defaults.set(now, forKey: Keys.lastDayReset)
    }

    private init() {
        // Initialize reset timestamps if not set
        let now = Date().timeIntervalSince1970
        if defaults.double(forKey: Keys.lastMinuteReset) == 0 {
            defaults.set(now, forKey: Keys.lastMinuteReset)
        }
        if defaults.double(forKey: Keys.lastHourReset) == 0 {
            defaults.set(now, forKey: Keys.lastHourReset)
        }
        if defaults.double(forKey: Keys.lastDayReset) == 0 {
            defaults.set(now, forKey: Keys.lastDayReset)
        }
    }
}

// MARK: - Usage Statistics

/// Current rate limit usage across all time windows
struct RateLimitUsage {
    let callsThisMinute: Int
    let callsThisHour: Int
    let callsThisDay: Int
    let maxPerMinute: Int
    let maxPerHour: Int
    let maxPerDay: Int

    /// Percentage of daily limit used (0.0 - 1.0)
    var dailyUsagePercentage: Double {
        guard maxPerDay > 0 else { return 0.0 }
        return Double(callsThisDay) / Double(maxPerDay)
    }

    /// Whether any limit is close to being exceeded (>80%)
    var isApproachingLimit: Bool {
        let minuteUsage = Double(callsThisMinute) / Double(maxPerMinute)
        let hourUsage = Double(callsThisHour) / Double(maxPerHour)
        let dayUsage = Double(callsThisDay) / Double(maxPerDay)

        return minuteUsage > 0.8 || hourUsage > 0.8 || dayUsage > 0.8
    }

    /// User-friendly status description
    var statusDescription: String {
        if callsThisDay >= maxPerDay {
            return "Daily limit reached"
        } else if callsThisHour >= maxPerHour {
            return "Hourly limit reached"
        } else if callsThisMinute >= maxPerMinute {
            return "Rate limited (too many requests)"
        } else if isApproachingLimit {
            return "Approaching limit"
        } else {
            return "Within limits"
        }
    }
}
