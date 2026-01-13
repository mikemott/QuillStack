//
//  NoteTypeConfig.swift
//  QuillStack
//
//  Configuration system for note types.
//  Provides declarative approach to defining note type display properties and views.
//  Coexists with plugin system during gradual migration.
//

import SwiftUI

// MARK: - Note Type Configuration

/// Configuration for a note type, defining its display properties and behavior.
/// This struct provides a simplified, declarative alternative to the plugin protocol.
///
/// Each config includes a `makeView` closure that creates the appropriate detail view,
/// following the Open/Closed Principle: new types can be added without modifying
/// the DetailViewFactory.
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

    /// Closure that creates the detail view for this note type.
    /// Encapsulates view creation logic within the config itself.
    let makeView: @MainActor @Sendable (Note) -> AnyView

    init(
        name: String,
        displayName: String,
        icon: String,
        badgeColor: Color,
        footerIcon: String,
        triggers: [String] = [],
        makeView: @MainActor @Sendable @escaping (Note) -> AnyView
    ) {
        self.name = name
        self.displayName = displayName
        self.icon = icon
        self.badgeColor = badgeColor
        self.footerIcon = footerIcon
        self.triggers = triggers
        self.makeView = makeView
    }
}

// MARK: - Note Type Config Registry

/// Singleton registry for note type configurations.
/// Provides centralized access to note type display properties and view types.
/// Thread-safe via concurrent dispatch queue.
final class NoteTypeConfigRegistry {

    // MARK: - Singleton

    static let shared = NoteTypeConfigRegistry()

    // MARK: - Storage

    private var configs: [String: NoteTypeConfig] = [:]
    private let accessQueue = DispatchQueue(
        label: "com.quillstack.NoteTypeConfigRegistry.accessQueue",
        attributes: .concurrent
    )

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
            makeView: { note in AnyView(NoteDetailView(note: note)) }
        ))

        // Todo/Task list
        register(NoteTypeConfig(
            name: "todo",
            displayName: "To-Do",
            icon: "checkmark.square",
            badgeColor: .badgeTodo,
            footerIcon: "checkmark.square",
            triggers: ["#todo#", "#to-do#", "#tasks#", "#task#"],
            makeView: { note in AnyView(TodoDetailView(note: note)) }
        ))

        // Email drafts
        register(NoteTypeConfig(
            name: "email",
            displayName: "Email",
            icon: "envelope",
            badgeColor: .badgeEmail,
            footerIcon: "paperplane",
            triggers: ["#email#", "#mail#"],
            makeView: { note in AnyView(EmailDetailView(note: note)) }
        ))

        // Meeting notes
        register(NoteTypeConfig(
            name: "meeting",
            displayName: "Meeting",
            icon: "calendar",
            badgeColor: .badgeMeeting,
            footerIcon: "person.2",
            triggers: ["#meeting#", "#notes#", "#minutes#"],
            makeView: { note in AnyView(MeetingDetailView(note: note)) }
        ))

        // Reminders
        register(NoteTypeConfig(
            name: "reminder",
            displayName: "Reminder",
            icon: "bell",
            badgeColor: .badgeReminder,
            footerIcon: "clock",
            triggers: ["#reminder#", "#remind#", "#remindme#"],
            makeView: { note in AnyView(ReminderDetailView(note: note)) }
        ))

        // Calendar events
        register(NoteTypeConfig(
            name: "event",
            displayName: "Event",
            icon: "calendar.badge.plus",
            badgeColor: .badgeEvent,
            footerIcon: "clock",
            triggers: ["#event#", "#appointment#", "#schedule#", "#appt#"],
            makeView: { note in AnyView(EventDetailView(note: note)) }
        ))

        // Expense/Receipt tracking
        register(NoteTypeConfig(
            name: "expense",
            displayName: "Expense",
            icon: "dollarsign.circle",
            badgeColor: .badgeExpense,
            footerIcon: "creditcard",
            triggers: ["#expense#", "#receipt#", "#spent#", "#paid#"],
            makeView: { note in AnyView(ExpenseDetailView(note: note)) }
        ))

        // Shopping lists
        register(NoteTypeConfig(
            name: "shopping",
            displayName: "Shopping",
            icon: "cart",
            badgeColor: .badgeShopping,
            footerIcon: "bag",
            triggers: ["#shopping#", "#shop#", "#grocery#", "#groceries#", "#list#"],
            makeView: { note in AnyView(ShoppingDetailView(note: note)) }
        ))

        // Recipes
        register(NoteTypeConfig(
            name: "recipe",
            displayName: "Recipe",
            icon: "fork.knife",
            badgeColor: .badgeRecipe,
            footerIcon: "list.bullet",
            triggers: ["#recipe#", "#cook#", "#bake#"],
            makeView: { note in AnyView(RecipeDetailView(note: note)) }
        ))

        // Ideas/brainstorming
        register(NoteTypeConfig(
            name: "idea",
            displayName: "Idea",
            icon: "lightbulb",
            badgeColor: .badgeIdea,
            footerIcon: "brain",
            triggers: ["#idea#", "#thought#", "#note-to-self#", "#notetoself#"],
            makeView: { note in AnyView(IdeaDetailView(note: note)) }
        ))

        // Claude prompts/feature requests
        register(NoteTypeConfig(
            name: "claudePrompt",
            displayName: "Feature",
            icon: "sparkles",
            badgeColor: .badgePrompt,
            footerIcon: "arrow.up.circle",
            triggers: ["#claude#", "#feature#", "#prompt#", "#request#", "#issue#"],
            makeView: { note in AnyView(ClaudePromptDetailView(note: note)) }
        ))

        // Contact/business cards
        register(NoteTypeConfig(
            name: "contact",
            displayName: "Contact",
            icon: "person.crop.circle",
            badgeColor: .badgeContact,
            footerIcon: "person",
            triggers: ["#contact#", "#person#", "#phone#"],
            makeView: { note in AnyView(ContactDetailView(note: note)) }
        ))
    }

    /// Register a custom note type configuration.
    /// - Parameter config: The configuration to register
    func register(_ config: NoteTypeConfig) {
        accessQueue.async(flags: .barrier) {
            self.configs[config.name] = config
        }
    }

    // MARK: - Lookup Methods

    /// Get the configuration for a specific note type.
    /// - Parameter noteType: The note type to look up
    /// - Returns: The configuration, or nil if not found
    func config(for noteType: NoteType) -> NoteTypeConfig? {
        accessQueue.sync {
            return configs[noteType.rawValue]
        }
    }

    /// Get the configuration by type name string.
    /// - Parameter name: The note type name (e.g., "todo")
    /// - Returns: The configuration, or nil if not found
    func config(forName name: String) -> NoteTypeConfig? {
        accessQueue.sync {
            return configs[name.lowercased()]
        }
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
        accessQueue.sync {
            return Array(configs.values)
        }
    }
}
