//
//  IntegrationRegistry.swift
//  QuillStack
//
//  Phase 4.1 - Architecture refactoring: central registry for integration providers.
//  Manages provider registration, lookup, and filtering by capabilities.
//

import Foundation
import Combine

/// Central registry for managing integration providers.
/// Use this class to register providers and query available integrations for note types.
@MainActor
@Observable
final class IntegrationRegistry {

    // MARK: - Singleton

    static let shared = IntegrationRegistry()

    // MARK: - Published State

    /// All registered providers (for UI binding)
    private(set) var allProviders: [any IntegrationProvider] = []

    /// Last registration change timestamp (for cache invalidation)
    private(set) var lastUpdated: Date = Date()

    // MARK: - Private Storage

    private var providers: [String: any IntegrationProvider] = [:]

    // MARK: - Initialization

    private init() {}

    /// Initialize with pre-registered providers (for testing)
    init(providers: [any IntegrationProvider]) {
        for provider in providers {
            self.providers[provider.id] = provider
        }
        self.allProviders = Array(self.providers.values)
    }

    // MARK: - Registration

    /// Register a new integration provider.
    /// - Parameter provider: The provider to register
    func register(_ provider: any IntegrationProvider) {
        providers[provider.id] = provider
        updatePublishedState()
    }

    /// Register multiple providers at once.
    /// - Parameter newProviders: Array of providers to register
    func register(_ newProviders: [any IntegrationProvider]) {
        for provider in newProviders {
            providers[provider.id] = provider
        }
        updatePublishedState()
    }

    /// Unregister a provider by ID.
    /// - Parameter providerId: ID of the provider to remove
    func unregister(_ providerId: String) {
        providers.removeValue(forKey: providerId)
        updatePublishedState()
    }

    /// Remove all registered providers.
    func unregisterAll() {
        providers.removeAll()
        updatePublishedState()
    }

    // MARK: - Lookup

    /// Get a provider by ID.
    /// - Parameter id: The provider ID
    /// - Returns: The provider if found, nil otherwise
    func provider(for id: String) -> (any IntegrationProvider)? {
        providers[id]
    }

    /// Get all providers that support a specific note type.
    /// - Parameter noteType: The note type to filter by
    /// - Returns: Array of providers supporting this note type
    func providers(supporting noteType: NoteType) -> [any IntegrationProvider] {
        providers.values.filter { $0.supportedNoteTypes.contains(noteType) }
    }

    /// Get all providers that are properly configured.
    /// - Returns: Array of configured providers
    func configuredProviders() async -> [any IntegrationProvider] {
        var configured: [any IntegrationProvider] = []
        for provider in providers.values {
            if await provider.isConfigured() {
                configured.append(provider)
            }
        }
        return configured
    }

    // MARK: - Capability Filtering

    /// Get all export-capable providers.
    /// - Returns: Array of providers that can export notes
    func exportProviders() -> [any ExportableProvider] {
        providers.values.compactMap { $0 as? any ExportableProvider }
    }

    /// Get export providers for a specific note type.
    /// - Parameter noteType: The note type to filter by
    /// - Returns: Array of export providers supporting this note type
    func exportProviders(for noteType: NoteType) -> [any ExportableProvider] {
        providers.values
            .compactMap { $0 as? any ExportableProvider }
            .filter { $0.supportedNoteTypes.contains(noteType) }
    }

    /// Get all sync-capable providers.
    /// - Returns: Array of providers that can sync notes
    func syncProviders() -> [any SyncableProvider] {
        providers.values.compactMap { $0 as? any SyncableProvider }
    }

    /// Get sync providers for a specific note type.
    /// - Parameter noteType: The note type to filter by
    /// - Returns: Array of sync providers supporting this note type
    func syncProviders(for noteType: NoteType) -> [any SyncableProvider] {
        providers.values
            .compactMap { $0 as? any SyncableProvider }
            .filter { $0.supportedNoteTypes.contains(noteType) }
    }

    /// Get all import-capable providers.
    /// - Returns: Array of providers that can import notes
    func importProviders() -> [any ImportableProvider] {
        providers.values.compactMap { $0 as? any ImportableProvider }
    }

    /// Get import providers for a specific note type.
    /// - Parameter noteType: The note type to filter by
    /// - Returns: Array of import providers supporting this note type
    func importProviders(for noteType: NoteType) -> [any ImportableProvider] {
        providers.values
            .compactMap { $0 as? any ImportableProvider }
            .filter { $0.supportedNoteTypes.contains(noteType) }
    }

    // MARK: - Configured Provider Lookup

    /// Get configured export providers for a note type.
    /// - Parameter noteType: The note type to filter by
    /// - Returns: Array of configured export providers
    func configuredExportProviders(for noteType: NoteType) async -> [any ExportableProvider] {
        var configured: [any ExportableProvider] = []
        for provider in exportProviders(for: noteType) {
            if await provider.isConfigured() {
                configured.append(provider)
            }
        }
        return configured
    }

    /// Get configured sync providers for a note type.
    /// - Parameter noteType: The note type to filter by
    /// - Returns: Array of configured sync providers
    func configuredSyncProviders(for noteType: NoteType) async -> [any SyncableProvider] {
        var configured: [any SyncableProvider] = []
        for provider in syncProviders(for: noteType) {
            if await provider.isConfigured() {
                configured.append(provider)
            }
        }
        return configured
    }

    // MARK: - Statistics

    /// Total number of registered providers.
    var count: Int { providers.count }

    /// Number of export-capable providers.
    var exportCount: Int { exportProviders().count }

    /// Number of sync-capable providers.
    var syncCount: Int { syncProviders().count }

    /// Number of import-capable providers.
    var importCount: Int { importProviders().count }

    /// Get a summary of provider capabilities.
    var capabilitySummary: CapabilitySummary {
        CapabilitySummary(
            total: count,
            export: exportCount,
            sync: syncCount,
            import: importCount
        )
    }

    // MARK: - Private Helpers

    private func updatePublishedState() {
        allProviders = Array(providers.values)
        lastUpdated = Date()
    }
}

// MARK: - Supporting Types

/// Summary of provider capabilities.
struct CapabilitySummary: Equatable, Sendable {
    let total: Int
    let export: Int
    let sync: Int
    let `import`: Int
}

// MARK: - Testing Support

extension IntegrationRegistry {
    /// Create a test instance with mock providers.
    /// - Parameter mockProviders: Providers to pre-register
    /// - Returns: A new registry instance for testing
    static func forTesting(with mockProviders: [any IntegrationProvider] = []) -> IntegrationRegistry {
        IntegrationRegistry(providers: mockProviders)
    }
}
