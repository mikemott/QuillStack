//
//  LLMCostTracker.swift
//  QuillStack
//
//  Basic cost tracking for LLM API usage
//
//  NOTE: recordUsage() is currently not integrated because LLMService.performAPIRequest()
//  does not return token counts. This will be integrated when the API response structure
//  is updated to include usage metadata. For now, this provides the infrastructure.
//

import Foundation

/// Tracks LLM API usage and estimated costs
@MainActor
final class LLMCostTracker {
    static let shared = LLMCostTracker()

    // Approximate cost per 1K tokens (Claude API pricing as of 2026)
    private let inputCostPer1KTokens = 0.003  // $0.003 per 1K input tokens
    private let outputCostPer1KTokens = 0.015 // $0.015 per 1K output tokens

    // Usage tracking
    private(set) var totalInputTokens: Int = 0
    private(set) var totalOutputTokens: Int = 0
    private(set) var totalCalls: Int = 0

    private init() {
        // Load from UserDefaults
        totalInputTokens = UserDefaults.standard.integer(forKey: "llm_total_input_tokens")
        totalOutputTokens = UserDefaults.standard.integer(forKey: "llm_total_output_tokens")
        totalCalls = UserDefaults.standard.integer(forKey: "llm_total_calls")
    }

    /// Record a completed LLM API call
    func recordUsage(inputTokens: Int, outputTokens: Int) {
        totalInputTokens += inputTokens
        totalOutputTokens += outputTokens
        totalCalls += 1

        // Persist to UserDefaults
        UserDefaults.standard.set(totalInputTokens, forKey: "llm_total_input_tokens")
        UserDefaults.standard.set(totalOutputTokens, forKey: "llm_total_output_tokens")
        UserDefaults.standard.set(totalCalls, forKey: "llm_total_calls")
    }

    /// Get estimated total cost in USD
    var estimatedCost: Double {
        let inputCost = Double(totalInputTokens) / 1000.0 * inputCostPer1KTokens
        let outputCost = Double(totalOutputTokens) / 1000.0 * outputCostPer1KTokens
        return inputCost + outputCost
    }

    /// Get usage summary for display
    func getUsageSummary() -> (calls: Int, tokens: Int, cost: Double) {
        let totalTokens = totalInputTokens + totalOutputTokens
        return (totalCalls, totalTokens, estimatedCost)
    }

    /// Reset all tracking (for testing or user request)
    func reset() {
        totalInputTokens = 0
        totalOutputTokens = 0
        totalCalls = 0

        UserDefaults.standard.removeObject(forKey: "llm_total_input_tokens")
        UserDefaults.standard.removeObject(forKey: "llm_total_output_tokens")
        UserDefaults.standard.removeObject(forKey: "llm_total_calls")
    }
}
