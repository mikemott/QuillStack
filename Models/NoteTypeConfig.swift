//
//  NoteTypeConfig.swift
//  QuillStack
//
//  Configuration system for note types.
//  Provides declarative approach to defining note type display properties and views.
//  Coexists with plugin system during gradual migration.
//

import SwiftUI

// MARK: - Detail View Type

/// Enumeration of all detail view types available for notes.
/// Maps note types to their corresponding detail view implementations.
enum DetailViewType: String, CaseIterable, Sendable {
    case general
    case todo
    case email
    case meeting
    case reminder
    case contact
    case expense
    case shopping
    case recipe
    case event
    case idea
    case claudePrompt
}

// MARK: - Note Type Configuration

/// Configuration for a note type, defining its display properties and behavior.
/// This struct provides a simplified, declarative alternative to the plugin protocol.
struct NoteTypeConfig: Sendable {
    /// Internal identifier for the config (e.g., "contact")
    let name: String

    /// Human-readable display name (e.g., "Contact")
    let displayName: String

    /// SF Symbol icon name for the note type
    let icon: String

    /// Badge color for type indicators
    let badgeColor: Color

    /// Footer icon for note cards (may differ from main icon)
    let footerIcon: String

    /// Hashtag triggers that activate this note type
    let triggers: [String]

    /// The detail view type to use for this note type
    let detailViewType: DetailViewType

    init(
        name: String,
        displayName: String,
        icon: String,
        badgeColor: Color,
        footerIcon: String,
        triggers: [String] = [],
        detailViewType: DetailViewType
    ) {
        self.name = name
        self.displayName = displayName
        self.icon = icon
        self.badgeColor = badgeColor
        self.footerIcon = footerIcon
        self.triggers = triggers
        self.detailViewType = detailViewType
    }
}

// MARK: - Note Type Config Registry

/// Singleton registry for note type configurations.
/// Provides centralized access to note type display properties and view types.
@MainActor
final class NoteTypeConfigRegistry {

    // MARK: - Singleton

    static let shared = NoteTypeConfigRegistry()

    // MARK: - Storage

    private var configs: [String: NoteTypeConfig] = [:]

    // MARK: - Initialization

    private init() {
        registerBuiltInTypes()
    }

    // MARK: - Registration

    /// Register all built-in note type configurations.
    /// Called automatically during initialization.
    private func registerBuiltInTypes() {
        // General note type (default/fallback)
        register(NoteTypeConfig(
            name: "general",
            displayName: "Note",
            icon: "doc.text",
            badgeColor: .badgeGeneral,
            footerIcon: "text.alignleft",
            triggers: [],
            detailViewType: .general
        ))

        // Todo/Task list
        register(NoteTypeConfig(
            name: "todo",
            displayName: "To-Do",
            icon: "checkmark.square",
            badgeColor: .badgeTodo,
            footerIcon: "checkmark.square",
            triggers: ["#todo#", "#to-do#", "#tasks#", "#task#"],
            detailViewType: .todo
        ))

        // Email drafts
        register(NoteTypeConfig(
            name: "email",
            displayName: "Email",
            icon: "envelope",
            badgeColor: .badgeEmail,
            footerIcon: "paperplane",
            triggers: ["#email#", "#mail#"],
            detailViewType: .email
        ))

        // Meeting notes
        register(NoteTypeConfig(
            name: "meeting",
            displayName: "Meeting",
            icon: "calendar",
            badgeColor: .badgeMeeting,
            footerIcon: "person.2",
            triggers: ["#meeting#", "#notes#", "#minutes#"],
            detailViewType: .meeting
        ))

        // Reminders
        register(NoteTypeConfig(
            name: "reminder",
            displayName: "Reminder",
            icon: "bell",
            badgeColor: .badgeReminder,
            footerIcon: "clock",
            triggers: ["#reminder#", "#remind#", "#remindme#"],
            detailViewType: .reminder
        ))

        // Calendar events
        register(NoteTypeConfig(
            name: "event",
            displayName: "Event",
            icon: "calendar.badge.plus",
            badgeColor: .badgeEvent,
            footerIcon: "clock",
            triggers: ["#event#", "#appointment#", "#schedule#", "#appt#"],
            detailViewType: .event
        ))

        // Expense/Receipt tracking
        register(NoteTypeConfig(
            name: "expense",
            displayName: "Expense",
            icon: "dollarsign.circle",
            badgeColor: .badgeExpense,
            footerIcon: "creditcard",
            triggers: ["#expense#", "#receipt#", "#spent#", "#paid#"],
            detailViewType: .expense
        ))

        // Shopping lists
        register(NoteTypeConfig(
            name: "shopping",
            displayName: "Shopping",
            icon: "cart",
            badgeColor: .badgeShopping,
            footerIcon: "bag",
            triggers: ["#shopping#", "#shop#", "#grocery#", "#groceries#", "#list#"],
            detailViewType: .shopping
        ))

        // Recipes
        register(NoteTypeConfig(
            name: "recipe",
            displayName: "Recipe",
            icon: "fork.knife",
            badgeColor: .badgeRecipe,
            footerIcon: "list.bullet",
            triggers: ["#recipe#", "#cook#", "#bake#"],
            detailViewType: .recipe
        ))

        // Ideas/brainstorming
        register(NoteTypeConfig(
            name: "idea",
            displayName: "Idea",
            icon: "lightbulb",
            badgeColor: .badgeIdea,
            footerIcon: "brain",
            triggers: ["#idea#", "#thought#", "#note-to-self#", "#notetoself#"],
            detailViewType: .idea
        ))

        // Claude prompts/feature requests
        register(NoteTypeConfig(
            name: "claudePrompt",
            displayName: "Feature",
            icon: "sparkles",
            badgeColor: .badgePrompt,
            footerIcon: "arrow.up.circle",
            triggers: ["#claude#", "#feature#", "#prompt#", "#request#", "#issue#"],
            detailViewType: .claudePrompt
        ))

        // Contact/business cards
        register(NoteTypeConfig(
            name: "contact",
            displayName: "Contact",
            icon: "person.crop.circle",
            badgeColor: .badgeContact,
            footerIcon: "person",
            triggers: ["#contact#", "#person#", "#phone#"],
            detailViewType: .contact
        ))
    }

    /// Register a custom note type configuration.
    /// - Parameter config: The configuration to register
    func register(_ config: NoteTypeConfig) {
        configs[config.name] = config
    }

    // MARK: - Lookup Methods

    /// Get the configuration for a specific note type.
    /// - Parameter noteType: The note type to look up
    /// - Returns: The configuration, or nil if not found
    func config(for noteType: NoteType) -> NoteTypeConfig? {
        return configs[noteType.rawValue]
    }

    /// Get the configuration by type name string.
    /// - Parameter name: The note type name (e.g., "todo")
    /// - Returns: The configuration, or nil if not found
    func config(forName name: String) -> NoteTypeConfig? {
        return configs[name]
    }

    /// Get display information for a note type.
    /// - Parameter noteType: The note type to look up
    /// - Returns: Tuple of (name, icon, color), or nil if not found
    func displayInfo(for noteType: NoteType) -> (name: String, icon: String, color: Color)? {
        guard let config = config(for: noteType) else { return nil }
        return (config.displayName, config.icon, config.badgeColor)
    }

    /// Get all registered configurations.
    /// - Returns: Array of all registered configs
    func allConfigs() -> [NoteTypeConfig] {
        return Array(configs.values)
    }
}
