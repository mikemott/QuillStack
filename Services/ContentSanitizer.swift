//
//  ContentSanitizer.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import Foundation
import os.log

// MARK: - Content Sanitizer

/// Sanitizes user content before sending to external LLM APIs
/// Detects and optionally redacts potentially sensitive information
@MainActor
final class ContentSanitizer {
    static let shared = ContentSanitizer()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "ContentSanitizer")

    private init() {}

    // MARK: - Sensitive Pattern Detection

    /// Patterns that may indicate sensitive content
    private let sensitivePatterns: [(name: String, pattern: String, replacement: String)] = [
        // Credit card numbers (basic pattern - 16 digits with optional separators)
        ("credit_card", #"\b\d{4}[- ]?\d{4}[- ]?\d{4}[- ]?\d{4}\b"#, "[CARD REDACTED]"),

        // Social Security Numbers (US format)
        ("ssn", #"\b\d{3}[- ]?\d{2}[- ]?\d{4}\b"#, "[SSN REDACTED]"),

        // API keys and tokens (common patterns)
        ("api_key", #"(?i)(sk-|api[_-]?key|token|secret)[:\s=]+['\"]?[\w\-]{20,}['\"]?"#, "[API KEY REDACTED]"),

        // Passwords in common formats
        ("password", #"(?i)(password|passwd|pwd)[:\s=]+['\"]?[^\s'\"]{6,}['\"]?"#, "[PASSWORD REDACTED]"),

        // Bearer tokens
        ("bearer", #"(?i)bearer\s+[\w\-\.]{20,}"#, "[BEARER TOKEN REDACTED]"),
    ]

    /// Patterns that are informational but not redacted by default
    private let informationalPatterns: [(name: String, pattern: String)] = [
        // Email addresses
        ("email", #"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"#),

        // Phone numbers (various formats)
        ("phone", #"\b(?:\+?1[- ]?)?(?:\(\d{3}\)|\d{3})[- ]?\d{3}[- ]?\d{4}\b"#),

        // URLs with potential auth tokens
        ("auth_url", #"https?://[^\s]*(?:token|key|auth|password|secret)=[^\s&]+"#),
    ]

    // MARK: - Public API

    /// Sanitizes content by redacting known sensitive patterns
    /// - Parameters:
    ///   - content: The original content to sanitize
    ///   - redactSecrets: Whether to redact API keys, passwords, etc. (default: true)
    /// - Returns: Sanitized content with sensitive data replaced
    func sanitize(_ content: String, redactSecrets: Bool = true) -> String {
        guard redactSecrets else { return content }

        var sanitized = content

        for (name, pattern, replacement) in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(sanitized.startIndex..., in: sanitized)
                let matches = regex.numberOfMatches(in: sanitized, options: [], range: range)

                if matches > 0 {
                    Self.logger.info("Redacted \(matches) \(name) pattern(s) before LLM API call")
                    sanitized = regex.stringByReplacingMatches(
                        in: sanitized,
                        options: [],
                        range: range,
                        withTemplate: replacement
                    )
                }
            }
        }

        return sanitized
    }

    /// Detects potentially sensitive content without modifying it
    /// - Parameter content: The content to analyze
    /// - Returns: List of detected sensitive content types
    func detectSensitiveContent(_ content: String) -> [String] {
        var detected: [String] = []

        // Check redactable patterns
        for (name, pattern, _) in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(content.startIndex..., in: content)
                if regex.firstMatch(in: content, options: [], range: range) != nil {
                    detected.append(name)
                }
            }
        }

        // Check informational patterns
        for (name, pattern) in informationalPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(content.startIndex..., in: content)
                if regex.firstMatch(in: content, options: [], range: range) != nil {
                    detected.append(name)
                }
            }
        }

        return detected
    }

    /// Checks if content contains any sensitive patterns that will be redacted
    /// - Parameter content: The content to check
    /// - Returns: True if sensitive patterns are found
    func containsSensitiveContent(_ content: String) -> Bool {
        for (_, pattern, _) in sensitivePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(content.startIndex..., in: content)
                if regex.firstMatch(in: content, options: [], range: range) != nil {
                    return true
                }
            }
        }
        return false
    }
}
