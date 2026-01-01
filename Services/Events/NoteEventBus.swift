//
//  NoteEventBus.swift
//  QuillStack
//
//  Phase 4.2 - Architecture refactoring: central event bus for loose coupling.
//  Enables components to publish and subscribe to note events without tight coupling.
//

import Foundation
import Combine
import os.log

// MARK: - Event Bus

/// Central event bus for publishing and subscribing to note events.
/// Use this to decouple components that need to react to note changes.
///
/// Example publishing:
/// ```swift
/// NoteEventBus.shared.publish(.created(noteId: note.id!, noteType: note.type), source: "CameraViewModel")
/// ```
///
/// Example subscribing:
/// ```swift
/// let subscriptionId = NoteEventBus.shared.subscribe { event in
///     print("Received event: \(event)")
/// }
/// // Later: NoteEventBus.shared.unsubscribe(subscriptionId)
/// ```
@MainActor
final class NoteEventBus: ObservableObject {

    // MARK: - Singleton

    static let shared = NoteEventBus()

    // MARK: - Logging

    private let logger = Logger(subsystem: "com.quillstack", category: "EventBus")

    // MARK: - Published State

    /// The most recent event (for SwiftUI binding)
    @Published private(set) var lastEvent: WrappedNoteEvent?

    /// Count of events published in this session
    @Published private(set) var eventCount: Int = 0

    // MARK: - Subscribers

    private var subscribers: [UUID: Subscription] = [:]

    // MARK: - Event History

    /// Recent events for debugging (limited size)
    private var recentEvents: [WrappedNoteEvent] = []
    private let maxHistorySize = 50

    // MARK: - Initialization

    private init() {}

    /// Create a test instance (not connected to shared state)
    init(forTesting: Bool) {
        // Isolated instance for testing
    }

    // MARK: - Publishing

    /// Publish an event to all subscribers.
    /// - Parameters:
    ///   - event: The event to publish
    ///   - source: The source component publishing this event
    ///   - context: Additional context as key-value pairs
    func publish(_ event: NoteEvent, source: String, context: [String: String] = [:]) {
        let wrapped = WrappedNoteEvent(event: event, source: source, context: context)
        publishWrapped(wrapped)
    }

    /// Publish a wrapped event (with pre-built metadata).
    /// - Parameter wrapped: The wrapped event to publish
    func publishWrapped(_ wrapped: WrappedNoteEvent) {
        // Update state
        lastEvent = wrapped
        eventCount += 1

        // Add to history
        recentEvents.append(wrapped)
        if recentEvents.count > maxHistorySize {
            recentEvents.removeFirst()
        }

        // Log the event
        logEvent(wrapped)

        // Notify subscribers
        for subscription in subscribers.values {
            if subscription.shouldReceive(wrapped.event) {
                subscription.handler(wrapped)
            }
        }
    }

    // MARK: - Subscribing

    /// Subscribe to all events.
    /// - Parameter handler: Closure called when any event is published
    /// - Returns: Subscription ID for later unsubscription
    @discardableResult
    func subscribe(handler: @escaping (WrappedNoteEvent) -> Void) -> UUID {
        let id = UUID()
        subscribers[id] = Subscription(handler: handler)
        logger.debug("New subscription: \(id.uuidString)")
        return id
    }

    /// Subscribe to events of specific categories.
    /// - Parameters:
    ///   - categories: Set of event categories to receive
    ///   - handler: Closure called when matching events are published
    /// - Returns: Subscription ID for later unsubscription
    @discardableResult
    func subscribe(
        to categories: Set<NoteEventCategory>,
        handler: @escaping (WrappedNoteEvent) -> Void
    ) -> UUID {
        let id = UUID()
        subscribers[id] = Subscription(
            categories: categories,
            handler: handler
        )
        logger.debug("New filtered subscription: \(id.uuidString) for categories: \(categories.map(\.rawValue).joined(separator: ", "))")
        return id
    }

    /// Subscribe to events for a specific note.
    /// - Parameters:
    ///   - noteId: The note ID to filter by
    ///   - handler: Closure called when events for this note are published
    /// - Returns: Subscription ID for later unsubscription
    @discardableResult
    func subscribe(
        forNote noteId: UUID,
        handler: @escaping (WrappedNoteEvent) -> Void
    ) -> UUID {
        let id = UUID()
        subscribers[id] = Subscription(
            noteId: noteId,
            handler: handler
        )
        logger.debug("New note-specific subscription: \(id.uuidString) for note: \(noteId.uuidString)")
        return id
    }

    /// Subscribe to events from a specific provider.
    /// - Parameters:
    ///   - providerName: The provider name to filter by
    ///   - handler: Closure called when events from this provider are published
    /// - Returns: Subscription ID for later unsubscription
    @discardableResult
    func subscribe(
        forProvider providerName: String,
        handler: @escaping (WrappedNoteEvent) -> Void
    ) -> UUID {
        let id = UUID()
        subscribers[id] = Subscription(
            providerName: providerName,
            handler: handler
        )
        logger.debug("New provider-specific subscription: \(id.uuidString) for provider: \(providerName)")
        return id
    }

    /// Unsubscribe from events.
    /// - Parameter id: The subscription ID returned from subscribe()
    func unsubscribe(_ id: UUID) {
        if subscribers.removeValue(forKey: id) != nil {
            logger.debug("Removed subscription: \(id.uuidString)")
        }
    }

    /// Remove all subscriptions.
    func unsubscribeAll() {
        let count = subscribers.count
        subscribers.removeAll()
        logger.debug("Removed all \(count) subscriptions")
    }

    // MARK: - Query

    /// Number of active subscriptions.
    var subscriberCount: Int { subscribers.count }

    /// Get recent events for debugging.
    /// - Parameter limit: Maximum number of events to return
    /// - Returns: Array of recent wrapped events (newest last)
    func recentEvents(limit: Int = 10) -> [WrappedNoteEvent] {
        Array(recentEvents.suffix(limit))
    }

    /// Get recent events of a specific category.
    /// - Parameters:
    ///   - category: The category to filter by
    ///   - limit: Maximum number of events to return
    /// - Returns: Array of recent wrapped events matching the category
    func recentEvents(category: NoteEventCategory, limit: Int = 10) -> [WrappedNoteEvent] {
        recentEvents
            .filter { $0.event.category == category }
            .suffix(limit)
            .map { $0 }
    }

    /// Get recent error events.
    /// - Parameter limit: Maximum number of events to return
    /// - Returns: Array of recent error events
    func recentErrors(limit: Int = 10) -> [WrappedNoteEvent] {
        recentEvents(category: .error, limit: limit)
    }

    /// Clear event history.
    func clearHistory() {
        recentEvents.removeAll()
        logger.debug("Cleared event history")
    }

    // MARK: - Combine Publisher

    /// Publisher for SwiftUI/Combine integration.
    var eventPublisher: AnyPublisher<WrappedNoteEvent, Never> {
        $lastEvent
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }

    // MARK: - Private Helpers

    private func logEvent(_ wrapped: WrappedNoteEvent) {
        let event = wrapped.event
        let source = wrapped.metadata.source

        switch event.category {
        case .lifecycle:
            logger.info("[\(source)] Lifecycle event: \(String(describing: event))")
        case .processing:
            logger.info("[\(source)] Processing event: \(String(describing: event))")
        case .integration:
            logger.info("[\(source)] Integration event: \(String(describing: event))")
        case .error:
            logger.error("[\(source)] Error event: \(String(describing: event))")
        }
    }
}

// MARK: - Subscription

/// Internal subscription representation.
private struct Subscription {
    let categories: Set<NoteEventCategory>?
    let noteId: UUID?
    let providerName: String?
    let handler: (WrappedNoteEvent) -> Void

    init(handler: @escaping (WrappedNoteEvent) -> Void) {
        self.categories = nil
        self.noteId = nil
        self.providerName = nil
        self.handler = handler
    }

    init(categories: Set<NoteEventCategory>, handler: @escaping (WrappedNoteEvent) -> Void) {
        self.categories = categories
        self.noteId = nil
        self.providerName = nil
        self.handler = handler
    }

    init(noteId: UUID, handler: @escaping (WrappedNoteEvent) -> Void) {
        self.categories = nil
        self.noteId = noteId
        self.providerName = nil
        self.handler = handler
    }

    init(providerName: String, handler: @escaping (WrappedNoteEvent) -> Void) {
        self.categories = nil
        self.noteId = nil
        self.providerName = providerName
        self.handler = handler
    }

    func shouldReceive(_ event: NoteEvent) -> Bool {
        // Check category filter
        if let categories = categories {
            guard categories.contains(event.category) else {
                return false
            }
        }

        // Check note ID filter
        if let noteId = noteId {
            guard event.noteId == noteId else {
                return false
            }
        }

        // Check provider filter
        if let providerName = providerName {
            guard event.providerName == providerName else {
                return false
            }
        }

        return true
    }
}

// MARK: - Convenience Extensions

extension NoteEventBus {
    /// Publish a note created event.
    func noteCreated(_ noteId: UUID, type: NoteType, source: String) {
        publish(.created(noteId: noteId, noteType: type), source: source)
    }

    /// Publish a note updated event.
    func noteUpdated(_ noteId: UUID, type: NoteType, source: String) {
        publish(.updated(noteId: noteId, noteType: type), source: source)
    }

    /// Publish a note deleted event.
    func noteDeleted(_ noteId: UUID, source: String) {
        publish(.deleted(noteId: noteId), source: source)
    }

    /// Publish an export completed event.
    func noteExported(_ noteId: UUID, provider: String, result: IntegrationExportResult, source: String) {
        publish(
            .exported(noteId: noteId, provider: provider, result: ExportEventResult(from: result)),
            source: source
        )
    }

    /// Publish an export failed event.
    func exportFailed(_ noteId: UUID, provider: String, error: Error, source: String) {
        publish(
            .exportFailed(noteId: noteId, provider: provider, error: error.localizedDescription),
            source: source
        )
    }
}

// MARK: - DependencyContainer Integration

extension DependencyContainer {
    /// Access to the event bus.
    var eventBus: NoteEventBus { NoteEventBus.shared }
}
