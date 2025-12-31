//
//  SettingsManager.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import Foundation
import Combine

// MARK: - Image Retention Policy

/// Policy options for retaining original images after OCR processing
enum ImageRetentionPolicy: String, CaseIterable, Codable {
    case keepForever = "keep_forever"
    case deleteAfterOCR = "delete_after_ocr"
    case deleteAfterDays = "delete_after_days"
    case deleteAfterExport = "delete_after_export"

    var displayName: String {
        switch self {
        case .keepForever: return "Keep Forever"
        case .deleteAfterOCR: return "Delete After OCR"
        case .deleteAfterDays: return "Delete After Time"
        case .deleteAfterExport: return "Delete After Export"
        }
    }

    var description: String {
        switch self {
        case .keepForever: return "Original images are stored indefinitely"
        case .deleteAfterOCR: return "Delete original images once text is extracted"
        case .deleteAfterDays: return "Keep images for a set number of days"
        case .deleteAfterExport: return "Delete after exporting to another app"
        }
    }

    var icon: String {
        switch self {
        case .keepForever: return "photo.badge.checkmark"
        case .deleteAfterOCR: return "text.viewfinder"
        case .deleteAfterDays: return "calendar.badge.clock"
        case .deleteAfterExport: return "square.and.arrow.up"
        }
    }
}

// MARK: - Onboarding Feature

/// Features that can be configured during onboarding
enum OnboardingFeature: String, CaseIterable, Codable {
    case aiEnhancement = "ai"
    case github = "github"
    case obsidian = "obsidian"
    case notion = "notion"
    case calendar = "calendar"

    var title: String {
        switch self {
        case .aiEnhancement: return "AI Enhancement"
        case .github: return "GitHub Issues"
        case .obsidian: return "Obsidian"
        case .notion: return "Notion"
        case .calendar: return "Calendar"
        }
    }

    var description: String {
        switch self {
        case .aiEnhancement: return "Fix OCR errors and summarize notes"
        case .github: return "Create issues from handwritten notes"
        case .obsidian: return "Export notes to your vault"
        case .notion: return "Sync notes to your workspace"
        case .calendar: return "Add meetings to your calendar"
        }
    }

    var icon: String {
        switch self {
        case .aiEnhancement: return "sparkles"
        case .github: return "arrow.triangle.branch"
        case .obsidian: return "cube"
        case .notion: return "doc.text"
        case .calendar: return "calendar"
        }
    }
}

// MARK: - Settings Manager

/// Central app settings management with secure credential storage
/// API keys are stored in Keychain; other settings use UserDefaults
@MainActor
final class SettingsManager: ObservableObject {
    static let shared = SettingsManager()

    private let defaults = UserDefaults.standard
    private let keychain = KeychainService.shared

    // MARK: - UserDefaults Keys

    private enum Keys {
        // Legacy keys (for migration)
        static let legacyClaudeAPIKey = "claudeAPIKey"
        static let legacyNotionAPIKey = "notionAPIKey"

        // Current keys
        static let autoEnhanceOCR = "autoEnhanceOCR"
        static let showLowConfidenceHighlights = "showLowConfidenceHighlights"
        static let lowConfidenceThreshold = "lowConfidenceThreshold"
        static let hasAcceptedAIDisclosure = "hasAcceptedAIDisclosure"

        // Export settings
        static let obsidianVaultPath = "obsidianVaultPath"
        static let obsidianDefaultFolder = "obsidianDefaultFolder"
        static let notionDefaultDatabaseId = "notionDefaultDatabaseId"
        static let includeOriginalImageDefault = "includeOriginalImageDefault"
        static let exportTagMappings = "exportTagMappings"
        static let defaultExportDestination = "defaultExportDestination"

        // Onboarding
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let selectedOnboardingFeatures = "selectedOnboardingFeatures"

        // Image Retention
        static let imageRetentionPolicy = "imageRetentionPolicy"
        static let autoDeleteOriginalImages = "autoDeleteOriginalImages"
        static let imageRetentionDays = "imageRetentionDays"
    }

    // MARK: - Initialization

    private init() {
        migrateFromUserDefaultsIfNeeded()
        loadSettings()
    }

    // MARK: - AI/Claude Settings (Keychain-backed)

    @Published var claudeAPIKey: String? = nil {
        didSet {
            if let key = claudeAPIKey, !key.isEmpty {
                try? keychain.save(key, for: .claudeAPIKey)
            } else {
                try? keychain.delete(for: .claudeAPIKey)
            }
        }
    }

    @Published var autoEnhanceOCR: Bool = false {
        didSet {
            defaults.set(autoEnhanceOCR, forKey: Keys.autoEnhanceOCR)
        }
    }

    @Published var hasAcceptedAIDisclosure: Bool = false {
        didSet {
            defaults.set(hasAcceptedAIDisclosure, forKey: Keys.hasAcceptedAIDisclosure)
        }
    }

    // MARK: - OCR Settings

    @Published var showLowConfidenceHighlights: Bool = true {
        didSet {
            defaults.set(showLowConfidenceHighlights, forKey: Keys.showLowConfidenceHighlights)
        }
    }

    @Published var lowConfidenceThreshold: Float = 0.7 {
        didSet {
            defaults.set(lowConfidenceThreshold, forKey: Keys.lowConfidenceThreshold)
        }
    }

    // MARK: - Export Settings

    @Published var obsidianVaultPath: String? = nil {
        didSet {
            if let path = obsidianVaultPath {
                defaults.set(path, forKey: Keys.obsidianVaultPath)
            } else {
                defaults.removeObject(forKey: Keys.obsidianVaultPath)
            }
        }
    }

    @Published var obsidianDefaultFolder: String = "QuillStack" {
        didSet {
            defaults.set(obsidianDefaultFolder, forKey: Keys.obsidianDefaultFolder)
        }
    }

    @Published var notionAPIKey: String? = nil {
        didSet {
            if let key = notionAPIKey, !key.isEmpty {
                try? keychain.save(key, for: .notionAPIKey)
            } else {
                try? keychain.delete(for: .notionAPIKey)
            }
        }
    }

    @Published var notionDefaultDatabaseId: String? = nil {
        didSet {
            if let id = notionDefaultDatabaseId {
                defaults.set(id, forKey: Keys.notionDefaultDatabaseId)
            } else {
                defaults.removeObject(forKey: Keys.notionDefaultDatabaseId)
            }
        }
    }

    @Published var includeOriginalImageDefault: Bool = false {
        didSet {
            defaults.set(includeOriginalImageDefault, forKey: Keys.includeOriginalImageDefault)
        }
    }

    @Published var exportTagMappings: [String: String] = [:] {
        didSet {
            defaults.set(exportTagMappings, forKey: Keys.exportTagMappings)
        }
    }

    @Published var defaultExportDestination: String = "apple_notes" {
        didSet {
            defaults.set(defaultExportDestination, forKey: Keys.defaultExportDestination)
        }
    }

    // MARK: - Onboarding Settings

    @Published var hasCompletedOnboarding: Bool = false {
        didSet {
            defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding)
        }
    }

    @Published var selectedOnboardingFeatures: Set<OnboardingFeature> = [] {
        didSet {
            let rawValues = selectedOnboardingFeatures.map { $0.rawValue }
            defaults.set(rawValues, forKey: Keys.selectedOnboardingFeatures)
        }
    }

    // MARK: - Image Retention Settings

    /// Policy for retaining original images after OCR
    @Published var imageRetentionPolicy: ImageRetentionPolicy = .keepForever {
        didSet {
            defaults.set(imageRetentionPolicy.rawValue, forKey: Keys.imageRetentionPolicy)
        }
    }

    /// Whether to automatically delete original images after OCR completes
    @Published var autoDeleteOriginalImages: Bool = false {
        didSet {
            defaults.set(autoDeleteOriginalImages, forKey: Keys.autoDeleteOriginalImages)
        }
    }

    /// Number of days to retain original images (used with .deleteAfterDays policy)
    @Published var imageRetentionDays: Int = 30 {
        didSet {
            defaults.set(imageRetentionDays, forKey: Keys.imageRetentionDays)
        }
    }

    // MARK: - Computed Properties

    var hasAPIKey: Bool {
        guard let key = claudeAPIKey else { return false }
        return !key.isEmpty
    }

    var hasObsidianVault: Bool {
        guard let path = obsidianVaultPath else { return false }
        return !path.isEmpty
    }

    var hasNotionAPIKey: Bool {
        guard let key = notionAPIKey else { return false }
        return !key.isEmpty
    }

    var hasNotionDatabase: Bool {
        guard let id = notionDefaultDatabaseId else { return false }
        return !id.isEmpty
    }

    /// Whether user needs to see the AI disclosure before first use
    var needsAIDisclosure: Bool {
        hasAPIKey && !hasAcceptedAIDisclosure
    }

    // MARK: - Loading

    private func loadSettings() {
        // Load from Keychain (secure)
        claudeAPIKey = keychain.retrieve(for: .claudeAPIKey)
        notionAPIKey = keychain.retrieve(for: .notionAPIKey)

        // Load from UserDefaults (non-sensitive)
        autoEnhanceOCR = defaults.bool(forKey: Keys.autoEnhanceOCR)
        hasAcceptedAIDisclosure = defaults.bool(forKey: Keys.hasAcceptedAIDisclosure)
        showLowConfidenceHighlights = defaults.object(forKey: Keys.showLowConfidenceHighlights) as? Bool ?? true
        lowConfidenceThreshold = defaults.object(forKey: Keys.lowConfidenceThreshold) as? Float ?? 0.7

        // Load export settings
        obsidianVaultPath = defaults.string(forKey: Keys.obsidianVaultPath)
        obsidianDefaultFolder = defaults.string(forKey: Keys.obsidianDefaultFolder) ?? "QuillStack"
        notionDefaultDatabaseId = defaults.string(forKey: Keys.notionDefaultDatabaseId)
        includeOriginalImageDefault = defaults.bool(forKey: Keys.includeOriginalImageDefault)
        exportTagMappings = defaults.dictionary(forKey: Keys.exportTagMappings) as? [String: String] ?? [:]
        defaultExportDestination = defaults.string(forKey: Keys.defaultExportDestination) ?? "apple_notes"

        // Load onboarding settings
        hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        if let rawFeatures = defaults.array(forKey: Keys.selectedOnboardingFeatures) as? [String] {
            selectedOnboardingFeatures = Set(rawFeatures.compactMap { OnboardingFeature(rawValue: $0) })
        }

        // Load image retention settings
        if let rawPolicy = defaults.string(forKey: Keys.imageRetentionPolicy),
           let policy = ImageRetentionPolicy(rawValue: rawPolicy) {
            imageRetentionPolicy = policy
        }
        autoDeleteOriginalImages = defaults.bool(forKey: Keys.autoDeleteOriginalImages)
        imageRetentionDays = defaults.object(forKey: Keys.imageRetentionDays) as? Int ?? 30
    }

    // MARK: - Migration

    /// Migrates API keys from insecure UserDefaults to secure Keychain
    /// This runs once on first launch after the update
    private func migrateFromUserDefaultsIfNeeded() {
        // Migrate Claude API key
        keychain.migrateFromUserDefaults(
            userDefaultsKey: Keys.legacyClaudeAPIKey,
            to: .claudeAPIKey
        )

        // Migrate Notion API key
        keychain.migrateFromUserDefaults(
            userDefaultsKey: Keys.legacyNotionAPIKey,
            to: .notionAPIKey
        )
    }

    // MARK: - API Key Validation

    /// Tests if the Claude API key is valid by making a minimal API call
    /// Uses LLMService's pinned session for secure communication
    func validateClaudeAPIKey() async -> Bool {
        guard let apiKey = claudeAPIKey, !apiKey.isEmpty else {
            return false
        }

        return await LLMService.shared.validateAPIKey(apiKey)
    }
}
