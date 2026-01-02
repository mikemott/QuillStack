//
//  NoteAction.swift
//  QuillStack
//
//  Phase A.1 - Core Action Models
//  Represents an action to be performed on a note, including its lifecycle state and result.
//

import Foundation

/// Represents an action to be performed on note content.
/// Tracks the action's lifecycle from creation through execution to completion.
struct NoteAction: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    let type: ActionType
    let prompt: String?              // For .ask, extended prompts
    let parameters: [String: String] // For .email recipient, .remind time
    let scope: ActionScope
    let createdAt: Date
    var status: ActionStatus
    var result: ActionResult?

    init(
        type: ActionType,
        prompt: String? = nil,
        parameters: [String: String] = [:],
        scope: ActionScope = .wholeNote
    ) {
        self.id = UUID()
        self.type = type
        self.prompt = prompt
        self.parameters = parameters
        self.scope = scope
        self.createdAt = Date()
        self.status = .pending
        self.result = nil
    }
}

// MARK: - ActionScope

/// Defines what portion of the note content an action operates on.
enum ActionScope: Codable, Equatable, Sendable {
    /// Operate on the entire note content
    case wholeNote
    /// Operate only on content above the `---` divider
    case beforeDivider
}

// MARK: - ActionStatus

/// Tracks the lifecycle state of an action.
enum ActionStatus: String, Codable, Sendable {
    /// Action is queued but not yet started
    case pending
    /// Action requires user confirmation before proceeding
    case awaitingConfirmation
    /// Action is currently being executed
    case executing
    /// Action completed successfully
    case completed
    /// Action failed during execution
    case failed
    /// Action was cancelled by the user
    case cancelled
}

// MARK: - ActionResult

/// Captures the outcome of an executed action.
struct ActionResult: Codable, Equatable, Sendable {
    let actionId: UUID
    let success: Bool
    let output: String?           // Generated summary, analysis, etc.
    let error: String?
    let executedAt: Date
    let metadata: [String: String] // Calendar event ID, email ID, etc.

    init(
        actionId: UUID,
        success: Bool,
        output: String? = nil,
        error: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.actionId = actionId
        self.success = success
        self.output = output
        self.error = error
        self.executedAt = Date()
        self.metadata = metadata
    }
}
