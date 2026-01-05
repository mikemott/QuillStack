//
//  NoteTypeRegistry.swift
//  QuillStack
//
//  Phase 4.4 - Architecture refactoring: central registry for note type plugins.
//  Manages plugin registration, lookup, and integration with existing systems.
//

import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - Note Type Registry

/// Central registry for note type plugins.
/// Use this to register, look up, and manage note type plugins.
///
/// Example registration:
/// ```swift
/// let todoPlugin = TodoNoteTypePlugin()
/// NoteTypeRegistry.shared.register(todoPlugin)
/// ```
///
/// Example lookup:
/// ```swift
/// if let plugin = NoteTypeRegistry.shared.plugin(for: .todo) {
///     let view = plugin.makeDetailView(for: note)
/// }
/// ```
@MainActor
@Observable
final class NoteTypeRegistry {

    // MARK: - Singleton

    static let shared = NoteTypeRegistry()

    // MARK: - Logging

    private let logger = Logger(subsystem: "com.quillstack", category: "NoteTypeRegistry")

    // MARK: - Published State

    /// Number of registered plugins
    private(set) var pluginCount: Int = 0

    /// Available note types (from registered plugins)
    private(set) var availableTypes: [NoteType] = []

    // MARK: - Storage

    /// Plugins indexed by ID
    private var pluginsById: [String: any NoteTypePlugin] = [:]

    /// Plugins indexed by NoteType
    private var pluginsByType: [NoteType: any NoteTypePlugin] = [:]

    /// Trigger to plugin mapping for classification
    private var triggerMap: [String: any NoteTypePlugin] = [:]

    // MARK: - Initialization

    private init() {
        logger.debug("NoteTypeRegistry initialized")
    }

    /// Create a test instance (not connected to shared state)
    init(forTesting: Bool) {
        // Isolated instance for testing
    }

    // MARK: - Registration

    /// Register a plugin.
    /// - Parameter plugin: The plugin to register
    /// - Returns: True if registration succeeded, false if a plugin with this ID already exists
    @discardableResult
    func register(_ plugin: any NoteTypePlugin) -> Bool {
        let id = plugin.id

        // Check for duplicate
        if pluginsById[id] != nil {
            logger.warning("Plugin with ID '\(id)' already registered, skipping")
            return false
        }

        // Store by ID
        pluginsById[id] = plugin

        // Store by type
        pluginsByType[plugin.type] = plugin

        // Build trigger map
        for trigger in plugin.triggers {
            let normalized = trigger.lowercased()
            if triggerMap[normalized] != nil {
                logger.warning("Trigger '\(trigger)' already mapped, overwriting with plugin '\(id)'")
            }
            triggerMap[normalized] = plugin
        }

        // Update published state
        pluginCount = pluginsById.count
        availableTypes = Array(pluginsByType.keys).sorted { $0.rawValue < $1.rawValue }

        logger.info("Registered plugin: \(plugin.displayName) (ID: \(id), type: \(plugin.type.rawValue))")

        return true
    }

    /// Register multiple plugins.
    /// - Parameter plugins: Array of plugins to register
    /// - Returns: Number of plugins successfully registered
    @discardableResult
    func register(_ plugins: [any NoteTypePlugin]) -> Int {
        var count = 0
        for plugin in plugins {
            if register(plugin) {
                count += 1
            }
        }
        return count
    }

    /// Unregister a plugin by ID.
    /// - Parameter id: The plugin ID to unregister
    /// - Returns: The unregistered plugin, or nil if not found
    @discardableResult
    func unregister(id: String) -> (any NoteTypePlugin)? {
        guard let plugin = pluginsById.removeValue(forKey: id) else {
            return nil
        }

        // Remove from type map
        pluginsByType.removeValue(forKey: plugin.type)

        // Remove triggers
        for trigger in plugin.triggers {
            triggerMap.removeValue(forKey: trigger.lowercased())
        }

        // Update published state
        pluginCount = pluginsById.count
        availableTypes = Array(pluginsByType.keys).sorted { $0.rawValue < $1.rawValue }

        logger.info("Unregistered plugin: \(plugin.displayName) (ID: \(id))")

        return plugin
    }

    /// Unregister a plugin by type.
    /// - Parameter type: The note type to unregister
    /// - Returns: The unregistered plugin, or nil if not found
    @discardableResult
    func unregister(type: NoteType) -> (any NoteTypePlugin)? {
        guard let plugin = pluginsByType[type] else {
            return nil
        }
        return unregister(id: plugin.id)
    }

    /// Remove all registered plugins.
    func unregisterAll() {
        let count = pluginsById.count
        pluginsById.removeAll()
        pluginsByType.removeAll()
        triggerMap.removeAll()
        pluginCount = 0
        availableTypes = []
        logger.info("Unregistered all \(count) plugins")
    }

    // MARK: - Lookup

    /// Get a plugin by ID.
    /// - Parameter id: The plugin ID
    /// - Returns: The plugin, or nil if not found
    func plugin(id: String) -> (any NoteTypePlugin)? {
        pluginsById[id]
    }

    /// Get a plugin for a note type.
    /// - Parameter type: The note type
    /// - Returns: The plugin, or nil if not found
    func plugin(for type: NoteType) -> (any NoteTypePlugin)? {
        pluginsByType[type]
    }

    /// Get a plugin by trigger.
    /// - Parameter trigger: The trigger string (e.g., "#todo#")
    /// - Returns: The plugin, or nil if no plugin handles this trigger
    func plugin(forTrigger trigger: String) -> (any NoteTypePlugin)? {
        triggerMap[trigger.lowercased()]
    }

    /// Check if a note type has a registered plugin.
    /// - Parameter type: The note type to check
    /// - Returns: True if a plugin is registered
    func hasPlugin(for type: NoteType) -> Bool {
        pluginsByType[type] != nil
    }

    /// Get all registered plugins.
    /// - Returns: Array of all plugins
    func allPlugins() -> [any NoteTypePlugin] {
        Array(pluginsById.values)
    }

    /// Get all registered plugin IDs.
    /// - Returns: Set of plugin IDs
    func allPluginIds() -> Set<String> {
        Set(pluginsById.keys)
    }

    // MARK: - View Factory

    /// Create a detail view for a note using the appropriate plugin.
    /// - Parameter note: The note to display
    /// - Returns: A view wrapped in AnyView, or nil if no plugin handles this type
    func makeDetailView(for note: Note) -> AnyView? {
        guard let plugin = pluginsByType[note.type] else {
            logger.debug("No plugin found for note type: \(note.type.rawValue)")
            return nil
        }
        return plugin.makeDetailView(for: note)
    }

    // MARK: - Classification

    /// Detect the note type from content using registered plugins.
    /// - Parameter content: The content to classify
    /// - Returns: The detected note type, or nil if no trigger matched
    func detectType(from content: String) -> NoteType? {
        let lowercased = content.lowercased()

        for (trigger, plugin) in triggerMap {
            if lowercased.contains(trigger) {
                logger.debug("Detected type \(plugin.type.rawValue) from trigger '\(trigger)'")
                return plugin.type
            }
        }

        return nil
    }

    /// Get all triggers for a note type.
    /// - Parameter type: The note type
    /// - Returns: Array of trigger strings
    func triggers(for type: NoteType) -> [String] {
        guard let plugin = pluginsByType[type] else {
            return []
        }
        return plugin.triggers
    }

    /// Get all registered triggers across all plugins.
    /// - Returns: Array of all trigger strings
    var allTriggers: [String] {
        Array(triggerMap.keys)
    }

    // MARK: - Plugin Information

    /// Get display information for a note type.
    /// - Parameter type: The note type
    /// - Returns: Tuple of (displayName, icon, badgeColor), or nil if no plugin
    func displayInfo(for type: NoteType) -> (name: String, icon: String, color: Color)? {
        guard let plugin = pluginsByType[type] else {
            return nil
        }
        return (plugin.displayName, plugin.icon, plugin.badgeColor)
    }

    /// Get footer icon for a note type.
    /// - Parameter type: The note type
    /// - Returns: SF Symbol name, or nil if no plugin
    func footerIcon(for type: NoteType) -> String? {
        pluginsByType[type]?.footerIcon
    }

    // MARK: - Integration

    /// Get all integration providers from all plugins.
    /// - Returns: Array of all integration providers
    func allIntegrationProviders() -> [any IntegrationProvider] {
        pluginsById.values.flatMap { $0.integrationProviders }
    }

    /// Get integration providers for a specific note type.
    /// - Parameter type: The note type
    /// - Returns: Array of integration providers, or empty if no plugin
    func integrationProviders(for type: NoteType) -> [any IntegrationProvider] {
        pluginsByType[type]?.integrationProviders ?? []
    }

    // MARK: - Lifecycle Events

    /// Notify plugins that a note was created.
    /// - Parameter note: The created note
    func notifyNoteCreated(_ note: Note) async {
        guard let plugin = pluginsByType[note.type] else { return }
        await plugin.onNoteCreated(note)
    }

    /// Notify plugins that a note was updated.
    /// - Parameter note: The updated note
    func notifyNoteUpdated(_ note: Note) async {
        guard let plugin = pluginsByType[note.type] else { return }
        await plugin.onNoteUpdated(note)
    }

    /// Notify plugins that a note was deleted.
    /// - Parameters:
    ///   - noteId: The deleted note ID
    ///   - type: The note type (needed since the note no longer exists)
    func notifyNoteDeleted(_ noteId: UUID, type: NoteType) async {
        guard let plugin = pluginsByType[type] else { return }
        await plugin.onNoteDeleted(noteId)
    }

    // MARK: - Debug

    /// Get a summary of registered plugins for debugging.
    var debugDescription: String {
        var lines = ["NoteTypeRegistry: \(pluginCount) plugins"]
        for plugin in pluginsById.values.sorted(by: { $0.id < $1.id }) {
            lines.append("  - \(plugin.id): \(plugin.displayName) (\(plugin.type.rawValue))")
            lines.append("    Triggers: \(plugin.triggers.joined(separator: ", "))")
            lines.append("    Capabilities: \(plugin.capabilities)")
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - DependencyContainer Integration

extension DependencyContainer {
    /// Access to the note type registry.
    var noteTypeRegistry: NoteTypeRegistry { NoteTypeRegistry.shared }
}

// MARK: - Built-in Plugin Registration

extension NoteTypeRegistry {
    /// Register all built-in plugins.
    /// Call this during app initialization.
    func registerBuiltInPlugins() {
        logger.info("Registering built-in plugins...")

        // General (default fallback - register first)
        register(GeneralNoteTypePlugin())

        // Core types
        register(TodoNoteTypePlugin())
        register(EmailNoteTypePlugin())
        register(MeetingNoteTypePlugin())

        // Integration types
        register(ReminderNoteTypePlugin())
        register(ContactNoteTypePlugin())
        register(EventNoteTypePlugin())

        // Utility types
        register(ExpenseNoteTypePlugin())
        register(ShoppingNoteTypePlugin())
        register(RecipeNoteTypePlugin())
        register(IdeaNoteTypePlugin())

        // Special types
        register(ClaudePromptNoteTypePlugin())

        logger.info("Registered \(self.pluginCount) built-in plugins")
    }
}
