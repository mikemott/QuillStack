//
//  LLMCostTracker.swift
//  QuillStack
//
//  Tracks LLM API usage costs and budget limits
//

import Foundation

/// Tracks LLM API token usage and estimated costs with budget management
/// Provides usage statistics, cost estimates, and budget alerts
@MainActor
final class LLMCostTracker {
    static let shared = LLMCostTracker()

    private let defaults = UserDefaults.standard

    // MARK: - Pricing Constants

    /// Claude Sonnet 4 pricing (as of 2026)
    private struct Pricing {
        static let inputPer1MTokens: Double = 3.00      // $3.00 per 1M input tokens
        static let outputPer1MTokens: Double = 15.00    // $15.00 per 1M output tokens
    }

    // MARK: - UserDefaults Keys

    private enum Keys {
        // Lifetime usage
        static let totalInputTokens = "llm_total_input_tokens"
        static let totalOutputTokens = "llm_total_output_tokens"
        static let totalCalls = "llm_total_calls"

        // Daily usage (resets daily)
        static let dailyInputTokens = "llm_daily_input_tokens"
        static let dailyOutputTokens = "llm_daily_output_tokens"
        static let dailyCalls = "llm_daily_calls"
        static let lastDailyReset = "llm_last_daily_reset"

        // Budget settings
        static let dailyBudgetUSD = "llm_daily_budget_usd"
        static let monthlyBudgetUSD = "llm_monthly_budget_usd"
        static let budgetAlertThreshold = "llm_budget_alert_threshold"

        // Monthly usage (resets monthly)
        static let monthlyInputTokens = "llm_monthly_input_tokens"
        static let monthlyOutputTokens = "llm_monthly_output_tokens"
        static let monthlyCalls = "llm_monthly_calls"
        static let lastMonthlyReset = "llm_last_monthly_reset"
    }

    // MARK: - Budget Configuration

    /// Default daily budget in USD ($5/day seems reasonable for typical usage)
    private static let defaultDailyBudget: Double = 5.00

    /// Default monthly budget in USD (~$150/month)
    private static let defaultMonthlyBudget: Double = 150.00

    /// Default alert threshold (0.8 = alert at 80% of budget)
    private static let defaultAlertThreshold: Double = 0.80

    var dailyBudgetUSD: Double {
        get {
            let value = defaults.double(forKey: Keys.dailyBudgetUSD)
            return value > 0 ? value : Self.defaultDailyBudget
        }
        set {
            defaults.set(newValue, forKey: Keys.dailyBudgetUSD)
        }
    }

    var monthlyBudgetUSD: Double {
        get {
            let value = defaults.double(forKey: Keys.monthlyBudgetUSD)
            return value > 0 ? value : Self.defaultMonthlyBudget
        }
        set {
            defaults.set(newValue, forKey: Keys.monthlyBudgetUSD)
        }
    }

    var budgetAlertThreshold: Double {
        get {
            let value = defaults.double(forKey: Keys.budgetAlertThreshold)
            return value > 0 ? value : Self.defaultAlertThreshold
        }
        set {
            defaults.set(newValue, forKey: Keys.budgetAlertThreshold)
        }
    }

    // MARK: - Usage Tracking

    /// Record a completed LLM API call with token usage
    /// - Parameters:
    ///   - inputTokens: Number of input tokens consumed
    ///   - outputTokens: Number of output tokens generated
    func recordUsage(inputTokens: Int, outputTokens: Int) {
        let now = Date()

        // Reset daily/monthly counters if needed
        resetExpiredWindows(currentTime: now)

        // Update lifetime totals
        let totalInput = defaults.integer(forKey: Keys.totalInputTokens)
        let totalOutput = defaults.integer(forKey: Keys.totalOutputTokens)
        let totalCalls = defaults.integer(forKey: Keys.totalCalls)

        defaults.set(totalInput + inputTokens, forKey: Keys.totalInputTokens)
        defaults.set(totalOutput + outputTokens, forKey: Keys.totalOutputTokens)
        defaults.set(totalCalls + 1, forKey: Keys.totalCalls)

        // Update daily totals
        let dailyInput = defaults.integer(forKey: Keys.dailyInputTokens)
        let dailyOutput = defaults.integer(forKey: Keys.dailyOutputTokens)
        let dailyCalls = defaults.integer(forKey: Keys.dailyCalls)

        defaults.set(dailyInput + inputTokens, forKey: Keys.dailyInputTokens)
        defaults.set(dailyOutput + outputTokens, forKey: Keys.dailyOutputTokens)
        defaults.set(dailyCalls + 1, forKey: Keys.dailyCalls)

        // Update monthly totals
        let monthlyInput = defaults.integer(forKey: Keys.monthlyInputTokens)
        let monthlyOutput = defaults.integer(forKey: Keys.monthlyOutputTokens)
        let monthlyCalls = defaults.integer(forKey: Keys.monthlyCalls)

        defaults.set(monthlyInput + inputTokens, forKey: Keys.monthlyInputTokens)
        defaults.set(monthlyOutput + outputTokens, forKey: Keys.monthlyOutputTokens)
        defaults.set(monthlyCalls + 1, forKey: Keys.monthlyCalls)
    }

    /// Reset counters for expired time windows
    private func resetExpiredWindows(currentTime: Date) {
        let calendar = Calendar.current

        // Daily reset (24 hours)
        let lastDailyReset = Date(timeIntervalSince1970: defaults.double(forKey: Keys.lastDailyReset))
        if !calendar.isDateInToday(lastDailyReset) {
            defaults.set(0, forKey: Keys.dailyInputTokens)
            defaults.set(0, forKey: Keys.dailyOutputTokens)
            defaults.set(0, forKey: Keys.dailyCalls)
            defaults.set(currentTime.timeIntervalSince1970, forKey: Keys.lastDailyReset)
        }

        // Monthly reset
        let lastMonthlyReset = Date(timeIntervalSince1970: defaults.double(forKey: Keys.lastMonthlyReset))
        if !calendar.isDate(lastMonthlyReset, equalTo: currentTime, toGranularity: .month) {
            defaults.set(0, forKey: Keys.monthlyInputTokens)
            defaults.set(0, forKey: Keys.monthlyOutputTokens)
            defaults.set(0, forKey: Keys.monthlyCalls)
            defaults.set(currentTime.timeIntervalSince1970, forKey: Keys.lastMonthlyReset)
        }
    }

    // MARK: - Cost Calculation

    /// Calculate cost for given token usage
    private func calculateCost(inputTokens: Int, outputTokens: Int) -> Double {
        let inputCost = Double(inputTokens) / 1_000_000.0 * Pricing.inputPer1MTokens
        let outputCost = Double(outputTokens) / 1_000_000.0 * Pricing.outputPer1MTokens
        return inputCost + outputCost
    }

    // MARK: - Usage Statistics

    /// Get current usage statistics
    func getCurrentUsage() -> CostUsage {
        let now = Date()
        resetExpiredWindows(currentTime: now)

        // Lifetime totals
        let totalInput = defaults.integer(forKey: Keys.totalInputTokens)
        let totalOutput = defaults.integer(forKey: Keys.totalOutputTokens)
        let totalCalls = defaults.integer(forKey: Keys.totalCalls)
        let lifetimeCost = calculateCost(inputTokens: totalInput, outputTokens: totalOutput)

        // Daily totals
        let dailyInput = defaults.integer(forKey: Keys.dailyInputTokens)
        let dailyOutput = defaults.integer(forKey: Keys.dailyOutputTokens)
        let dailyCalls = defaults.integer(forKey: Keys.dailyCalls)
        let dailyCost = calculateCost(inputTokens: dailyInput, outputTokens: dailyOutput)

        // Monthly totals
        let monthlyInput = defaults.integer(forKey: Keys.monthlyInputTokens)
        let monthlyOutput = defaults.integer(forKey: Keys.monthlyOutputTokens)
        let monthlyCalls = defaults.integer(forKey: Keys.monthlyCalls)
        let monthlyCost = calculateCost(inputTokens: monthlyInput, outputTokens: monthlyOutput)

        return CostUsage(
            // Lifetime
            totalInputTokens: totalInput,
            totalOutputTokens: totalOutput,
            totalCalls: totalCalls,
            lifetimeCost: lifetimeCost,
            // Daily
            dailyInputTokens: dailyInput,
            dailyOutputTokens: dailyOutput,
            dailyCalls: dailyCalls,
            dailyCost: dailyCost,
            dailyBudget: dailyBudgetUSD,
            // Monthly
            monthlyInputTokens: monthlyInput,
            monthlyOutputTokens: monthlyOutput,
            monthlyCalls: monthlyCalls,
            monthlyCost: monthlyCost,
            monthlyBudget: monthlyBudgetUSD,
            // Budget
            budgetAlertThreshold: budgetAlertThreshold
        )
    }

    /// Check if user is approaching or exceeding budget
    func checkBudgetStatus() -> BudgetStatus {
        let usage = getCurrentUsage()

        // Check daily budget
        if usage.dailyCost >= dailyBudgetUSD {
            return .exceeded(.daily, usage.dailyCost, dailyBudgetUSD)
        } else if usage.dailyCost >= dailyBudgetUSD * budgetAlertThreshold {
            return .approaching(.daily, usage.dailyCost, dailyBudgetUSD)
        }

        // Check monthly budget
        if usage.monthlyCost >= monthlyBudgetUSD {
            return .exceeded(.monthly, usage.monthlyCost, monthlyBudgetUSD)
        } else if usage.monthlyCost >= monthlyBudgetUSD * budgetAlertThreshold {
            return .approaching(.monthly, usage.monthlyCost, monthlyBudgetUSD)
        }

        return .withinBudget
    }

    /// Reset all usage statistics (for testing or user request)
    func resetAllUsage() {
        // Lifetime
        defaults.removeObject(forKey: Keys.totalInputTokens)
        defaults.removeObject(forKey: Keys.totalOutputTokens)
        defaults.removeObject(forKey: Keys.totalCalls)

        // Daily
        defaults.removeObject(forKey: Keys.dailyInputTokens)
        defaults.removeObject(forKey: Keys.dailyOutputTokens)
        defaults.removeObject(forKey: Keys.dailyCalls)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastDailyReset)

        // Monthly
        defaults.removeObject(forKey: Keys.monthlyInputTokens)
        defaults.removeObject(forKey: Keys.monthlyOutputTokens)
        defaults.removeObject(forKey: Keys.monthlyCalls)
        defaults.set(Date().timeIntervalSince1970, forKey: Keys.lastMonthlyReset)
    }

    private init() {
        // Initialize reset timestamps if not set
        let now = Date().timeIntervalSince1970
        if defaults.double(forKey: Keys.lastDailyReset) == 0 {
            defaults.set(now, forKey: Keys.lastDailyReset)
        }
        if defaults.double(forKey: Keys.lastMonthlyReset) == 0 {
            defaults.set(now, forKey: Keys.lastMonthlyReset)
        }
    }
}

// MARK: - Supporting Types

/// Current usage statistics across all time periods
struct CostUsage {
    // Lifetime totals
    let totalInputTokens: Int
    let totalOutputTokens: Int
    let totalCalls: Int
    let lifetimeCost: Double

    // Daily totals
    let dailyInputTokens: Int
    let dailyOutputTokens: Int
    let dailyCalls: Int
    let dailyCost: Double
    let dailyBudget: Double

    // Monthly totals
    let monthlyInputTokens: Int
    let monthlyOutputTokens: Int
    let monthlyCalls: Int
    let monthlyCost: Double
    let monthlyBudget: Double

    // Budget settings
    let budgetAlertThreshold: Double

    /// Total tokens (lifetime)
    var totalTokens: Int {
        totalInputTokens + totalOutputTokens
    }

    /// Daily budget usage percentage (0.0 - 1.0+)
    var dailyBudgetUsage: Double {
        guard dailyBudget > 0 else { return 0.0 }
        return dailyCost / dailyBudget
    }

    /// Monthly budget usage percentage (0.0 - 1.0+)
    var monthlyBudgetUsage: Double {
        guard monthlyBudget > 0 else { return 0.0 }
        return monthlyCost / monthlyBudget
    }

    /// Average cost per call (lifetime)
    var averageCostPerCall: Double {
        guard totalCalls > 0 else { return 0.0 }
        return lifetimeCost / Double(totalCalls)
    }
}

/// Budget status for alerts
enum BudgetStatus {
    case withinBudget
    case approaching(BudgetPeriod, Double, Double)  // period, current, limit
    case exceeded(BudgetPeriod, Double, Double)     // period, current, limit

    var shouldAlert: Bool {
        switch self {
        case .withinBudget:
            return false
        case .approaching, .exceeded:
            return true
        }
    }

    var alertMessage: String? {
        switch self {
        case .withinBudget:
            return nil
        case .approaching(let period, let current, let limit):
            let percentage = Int((current / limit) * 100)
            return "Approaching \(period.rawValue) budget: $\(String(format: "%.2f", current)) of $\(String(format: "%.2f", limit)) (\(percentage)%)"
        case .exceeded(let period, let current, let limit):
            return "\(period.rawValue.capitalized) budget exceeded: $\(String(format: "%.2f", current)) of $\(String(format: "%.2f", limit))"
        }
    }
}

enum BudgetPeriod: String {
    case daily = "daily"
    case monthly = "monthly"
}
