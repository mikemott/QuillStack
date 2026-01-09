//
//  CrossLinkingService.swift
//  QuillStack
//
//  Created on 2026-01-09.
//  QUI-161: Automatic Cross-Linking
//

import Foundation
import CoreData

/// Service for automatically finding and creating links between related notes
@MainActor
final class CrossLinkingService {
    static let shared = CrossLinkingService()

    private let llmService: LLMServiceProtocol
    private let coreDataStack: CoreDataStack

    /// Minimum confidence threshold for creating links (0.75 as per requirements)
    private let confidenceThreshold: Double = 0.75

    /// Maximum number of candidate notes to send to LLM for analysis
    private let maxCandidateNotes: Int = 50

    private init(
        llmService: LLMServiceProtocol = LLMService.shared,
        coreDataStack: CoreDataStack = CoreDataStack.shared
    ) {
        self.llmService = llmService
        self.coreDataStack = coreDataStack
    }

    // MARK: - Public API

    /// Analyze a note and create automatic links to related notes
    /// - Parameter note: The note to analyze
    /// - Returns: Number of links created
    @discardableResult
    func analyzeAndLinkNote(_ note: Note) async throws -> Int {
        let startTime = Date()

        // Fetch candidate notes (exclude archived and the note itself)
        let candidates = try await fetchCandidateNotes(excluding: note.id)

        guard !candidates.isEmpty else {
            return 0 // No notes to link to
        }

        // Build the LLM prompt with note content and candidates
        let prompt = buildAnalysisPrompt(for: note, candidates: candidates)

        // Call LLM to find relationships
        let jsonResponse = try await llmService.performRequest(prompt: prompt, maxTokens: 2048)

        // Parse the response
        guard let jsonData = jsonResponse.data(using: .utf8) else {
            throw CrossLinkingError.invalidResponse
        }

        let decoder = JSONDecoder()
        let result = try decoder.decode(CrossLinkingResult.self, from: jsonData)

        // Filter by confidence threshold
        let highConfidenceLinks = result.relationships.filter { $0.confidence > confidenceThreshold }

        // Create bidirectional links in a background context
        let createdCount = try await createLinks(
            from: note.id,
            relationships: highConfidenceLinks
        )

        let duration = Date().timeIntervalSince(startTime)
        print("✓ Cross-linking analysis completed in \(String(format: "%.2f", duration))s - created \(createdCount) links")

        return createdCount
    }

    /// Remove automatic links for a note (useful when user wants to reset)
    func removeAutomaticLinks(for noteId: UUID) async throws {
        let backgroundContext = coreDataStack.newBackgroundContext()

        try await backgroundContext.perform {
            let fetchRequest = NSFetchRequest<NoteLink>(entityName: "NoteLink")
            fetchRequest.predicate = NSPredicate(
                format: "(sourceNote.id == %@ OR targetNote.id == %@) AND isAutomatic == YES",
                noteId as CVarArg, noteId as CVarArg
            )

            let links = try backgroundContext.fetch(fetchRequest)
            for link in links {
                backgroundContext.delete(link)
            }

            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }
        }
    }

    // MARK: - Private Helpers

    /// Fetch candidate notes for linking (non-archived, recent notes)
    private func fetchCandidateNotes(excluding noteId: UUID) async throws -> [CandidateNote] {
        let backgroundContext = coreDataStack.newBackgroundContext()

        return try await backgroundContext.perform {
            let fetchRequest = NSFetchRequest<Note>(entityName: "Note")
            fetchRequest.predicate = NSPredicate(
                format: "isArchived == NO AND id != %@",
                noteId as CVarArg
            )
            fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            fetchRequest.fetchLimit = self.maxCandidateNotes

            let notes = try backgroundContext.fetch(fetchRequest)

            return notes.map { note in
                CandidateNote(
                    id: note.id,
                    content: note.content,
                    noteType: note.noteType,
                    createdAt: note.createdAt,
                    tags: note.tags
                )
            }
        }
    }

    /// Build the LLM prompt for relationship analysis
    private func buildAnalysisPrompt(for note: Note, candidates: [CandidateNote]) -> String {
        // Format candidates for the prompt (truncate content if too long)
        let candidatesText = candidates.map { candidate in
            let truncatedContent = candidate.content.prefix(200)
            let tagsText = candidate.tags ?? "none"
            return """
            ID: \(candidate.id)
            Type: \(candidate.noteType)
            Tags: \(tagsText)
            Content: \(truncatedContent)\(candidate.content.count > 200 ? "..." : "")
            ---
            """
        }.joined(separator: "\n")

        let prompt = """
        You are helping find related notes in a handwritten note-taking app.

        Analyze the NEW NOTE below and identify related notes from the CANDIDATE NOTES list.

        ## NEW NOTE
        Type: \(note.noteType)
        Tags: \(note.tags ?? "none")
        Content:
        \(note.content)

        ## CANDIDATE NOTES
        \(candidatesText)

        ## RELATIONSHIP TYPES

        Find connections based on these criteria:

        1. **mentions_same_person**: Both notes mention the same person (e.g., "Sarah", "Mike Mott")
        2. **same_topic**: Both notes are about the same topic or project (e.g., "Q4 budget", "website redesign")
        3. **temporal_relationship**: One note is a follow-up or preparation for another (e.g., meeting prep → meeting notes)
        4. **semantic_similarity**: Notes have similar meaning or intent, even if worded differently

        ## RULES

        - Only include relationships with confidence > 0.75
        - Be conservative - false positives are worse than false negatives
        - Consider the note type and context
        - A note can have multiple relationships to different notes
        - Return an empty array if no strong relationships exist

        ## RESPONSE FORMAT

        Return ONLY valid JSON with this structure (no markdown code blocks, no explanations):

        {
          "relationships": [
            {
              "targetNoteId": "uuid-of-related-note",
              "relationshipType": "mentions_same_person",
              "confidence": 0.85,
              "reason": "Brief explanation of why they're related"
            }
          ]
        }

        If no relationships found, return: {"relationships": []}
        """

        return prompt
    }

    /// Create bidirectional links in a background context
    private func createLinks(
        from sourceNoteId: UUID,
        relationships: [Relationship]
    ) async throws -> Int {
        guard !relationships.isEmpty else { return 0 }

        let backgroundContext = coreDataStack.newBackgroundContext()

        return try await backgroundContext.perform {
            // Fetch the source note
            let sourceFetch = NSFetchRequest<Note>(entityName: "Note")
            sourceFetch.predicate = NSPredicate(format: "id == %@", sourceNoteId as CVarArg)

            guard let sourceNote = try backgroundContext.fetch(sourceFetch).first else {
                throw CrossLinkingError.noteNotFound
            }

            var createdCount = 0

            for relationship in relationships {
                // Fetch the target note
                let targetFetch = NSFetchRequest<Note>(entityName: "Note")
                targetFetch.predicate = NSPredicate(format: "id == %@", relationship.targetNoteId as CVarArg)

                guard let targetNote = try backgroundContext.fetch(targetFetch).first else {
                    print("⚠️ Target note not found: \(relationship.targetNoteId)")
                    continue
                }

                // Check if link already exists (avoid duplicates)
                if self.linkExists(from: sourceNote, to: targetNote, type: relationship.relationshipType, in: backgroundContext) {
                    continue
                }

                // Create forward link (source → target)
                let forwardLink = NoteLink.create(
                    in: backgroundContext,
                    from: sourceNote,
                    to: targetNote,
                    type: relationship.relationshipType,
                    label: relationship.reason,
                    confidence: relationship.confidence,
                    isAutomatic: true
                )

                // Create backward link (target → source) for bidirectional relationship
                let backwardLink = NoteLink.create(
                    in: backgroundContext,
                    from: targetNote,
                    to: sourceNote,
                    type: relationship.relationshipType,
                    label: relationship.reason,
                    confidence: relationship.confidence,
                    isAutomatic: true
                )

                createdCount += 2 // Count both directions
            }

            // Save all changes
            if backgroundContext.hasChanges {
                try backgroundContext.save()
            }

            return createdCount
        }
    }

    /// Check if a link already exists between two notes
    private func linkExists(
        from source: Note,
        to target: Note,
        type: LinkType,
        in context: NSManagedObjectContext
    ) -> Bool {
        let fetchRequest = NSFetchRequest<NoteLink>(entityName: "NoteLink")
        fetchRequest.predicate = NSPredicate(
            format: "sourceNote == %@ AND targetNote == %@ AND linkType == %@",
            source, target, type.rawValue
        )
        fetchRequest.fetchLimit = 1

        let count = (try? context.count(for: fetchRequest)) ?? 0
        return count > 0
    }
}

// MARK: - Error Types

enum CrossLinkingError: LocalizedError {
    case invalidResponse
    case noteNotFound
    case noRelationshipsFound

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from AI service while analyzing note relationships."
        case .noteNotFound:
            return "Note not found in database."
        case .noRelationshipsFound:
            return "No related notes found."
        }
    }
}

// MARK: - Data Models

/// Lightweight representation of a candidate note for LLM analysis
private struct CandidateNote: Codable {
    let id: UUID
    let content: String
    let noteType: String
    let createdAt: Date
    let tags: String?
}

/// Result from LLM cross-linking analysis
struct CrossLinkingResult: Codable {
    let relationships: [Relationship]
}

/// A relationship between two notes identified by the LLM
struct Relationship: Codable {
    let targetNoteId: UUID
    let relationshipType: LinkType
    let confidence: Double
    let reason: String // Brief explanation
}
