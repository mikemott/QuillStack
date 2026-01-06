//
//  NoteClassification.swift
//  QuillStack
//
//  Phase 1 - Intelligent Classification
//  Represents the result of classifying a note, including confidence and method.
//

import Foundation

/// Represents how a note was classified, including confidence and method.
struct NoteClassification: Equatable, Sendable {
    /// The detected note type
    let type: NoteType
    
    /// Confidence score from 0.0 to 1.0
    /// - 1.0 = Explicit (hashtag) - 100% confident
    /// - 0.85-0.95 = LLM classification - high confidence
    /// - 0.70-0.85 = Heuristic detection - medium confidence
    /// - 0.50-0.70 = Content analysis - low confidence
    /// - < 0.50 = Default/unknown - very low confidence
    let confidence: Double
    
    /// How the classification was determined
    let method: ClassificationMethod
    
    /// Optional reasoning for debugging/transparency
    /// e.g., "Detected phone + email pattern", "LLM identified meeting keywords"
    let reasoning: String?

    /// Prompt version used for LLM classification (only set when method == .llm)
    /// Used for A/B testing and rollback capability
    let promptVersion: String?

    init(
        type: NoteType,
        confidence: Double,
        method: ClassificationMethod,
        reasoning: String? = nil,
        promptVersion: String? = nil
    ) {
        self.type = type
        self.confidence = confidence
        self.method = method
        self.reasoning = reasoning
        self.promptVersion = promptVersion
    }
    
    /// Creates a classification with explicit (hashtag) method
    static func explicit(_ type: NoteType) -> NoteClassification {
        NoteClassification(
            type: type,
            confidence: 1.0,
            method: .explicit,
            reasoning: "Explicit hashtag trigger detected"
        )
    }
    
    /// Creates a classification with LLM method
    static func llm(_ type: NoteType, confidence: Double = 0.85, reasoning: String? = nil, promptVersion: String? = nil) -> NoteClassification {
        NoteClassification(
            type: type,
            confidence: confidence,
            method: .llm,
            reasoning: reasoning,
            promptVersion: promptVersion
        )
    }
    
    /// Creates a classification with heuristic method
    static func heuristic(_ type: NoteType, confidence: Double = 0.75, reasoning: String? = nil) -> NoteClassification {
        NoteClassification(
            type: type,
            confidence: confidence,
            method: .heuristic,
            reasoning: reasoning
        )
    }
    
    /// Creates a classification with manual (user-corrected) method
    static func manual(_ type: NoteType) -> NoteClassification {
        NoteClassification(
            type: type,
            confidence: 1.0,
            method: .manual,
            reasoning: "Manually corrected by user"
        )
    }
    
    /// Creates a default classification
    static func `default`(_ type: NoteType = .general) -> NoteClassification {
        NoteClassification(
            type: type,
            confidence: 0.5,
            method: .default,
            reasoning: "Default classification"
        )
    }
}

// MARK: - ClassificationMethod

/// How a note classification was determined
enum ClassificationMethod: String, Codable, Sendable {
    /// Explicit hashtag trigger (#todo#, #meeting#)
    case explicit
    
    /// LLM-powered intelligent classification
    case llm
    
    /// Heuristic-based detection (regex, patterns)
    case heuristic
    
    /// Voice command detection
    case voiceCommand
    
    /// Content analysis (keyword matching)
    case contentAnalysis
    
    /// Manually corrected by user
    case manual
    
    /// Default fallback
    case `default`
    
    /// Human-readable description
    var displayName: String {
        switch self {
        case .explicit: return "Hashtag"
        case .llm: return "AI Detection"
        case .heuristic: return "Pattern Match"
        case .voiceCommand: return "Voice Command"
        case .contentAnalysis: return "Content Analysis"
        case .manual: return "Manual"
        case .default: return "Default"
        }
    }
    
    /// Whether this method is considered "automatic" (not user-driven)
    var isAutomatic: Bool {
        switch self {
        case .explicit, .manual:
            return false
        case .llm, .heuristic, .voiceCommand, .contentAnalysis, .default:
            return true
        }
    }
}

// MARK: - Convenience Extensions

extension NoteClassification {
    /// Whether this classification is high confidence (>= 0.85)
    var isHighConfidence: Bool {
        confidence >= 0.85
    }
    
    /// Whether this classification is low confidence (< 0.70)
    var isLowConfidence: Bool {
        confidence < 0.70
    }
    
    /// Whether user should be asked to confirm this classification
    var shouldRequestConfirmation: Bool {
        confidence < 0.80 && method != .explicit && method != .manual
    }
    
    /// Formatted confidence percentage for display
    var confidencePercentage: String {
        "\(Int(confidence * 100))%"
    }
}

