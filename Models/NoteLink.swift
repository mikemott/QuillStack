//
//  NoteLink.swift
//  QuillStack
//
//  Created on 2026-01-06.
//

import Foundation
import CoreData

/// Represents a directional link between two notes
@objc(NoteLink)
public class NoteLink: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var createdAt: Date
    @NSManaged public var linkType: String // LinkType enum rawValue
    @NSManaged public var label: String? // Optional custom label

    // Relationships
    @NSManaged public var sourceNote: Note
    @NSManaged public var targetNote: Note

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        linkType = LinkType.reference.rawValue
        label = nil
    }
}

// MARK: - Link Type Enum

/// Types of relationships between notes
public enum LinkType: String, Codable, CaseIterable {
    case reference      // General reference
    case parent         // Target is parent of source
    case child          // Target is child of source
    case related        // Bidirectional relationship
    case duplicate      // Same content, different capture
    case implements     // Target implements idea from source
    case continues      // Target continues thought from source

    /// Human-readable description of the link type
    var description: String {
        switch self {
        case .reference: return "References"
        case .parent: return "Parent"
        case .child: return "Child"
        case .related: return "Related to"
        case .duplicate: return "Duplicate of"
        case .implements: return "Implements"
        case .continues: return "Continues"
        }
    }

    /// Icon for the link type
    var icon: String {
        switch self {
        case .reference: return "arrow.right"
        case .parent: return "arrow.up"
        case .child: return "arrow.down"
        case .related: return "arrow.left.arrow.right"
        case .duplicate: return "doc.on.doc"
        case .implements: return "checkmark.circle"
        case .continues: return "arrow.right.circle"
        }
    }
}

// MARK: - Convenience Extensions

extension NoteLink {
    /// Typed link type accessor
    var type: LinkType {
        get {
            LinkType(rawValue: linkType) ?? .reference
        }
        set {
            linkType = newValue.rawValue
        }
    }

    /// Get the display label for this link
    var displayLabel: String {
        label ?? type.description
    }

    /// Check if this link is bidirectional
    var isBidirectional: Bool {
        type == .related
    }

    /// Create a new link in the given context
    static func create(
        in context: NSManagedObjectContext,
        from source: Note,
        to target: Note,
        type: LinkType = .reference,
        label: String? = nil
    ) -> NoteLink {
        let link = NoteLink(context: context)
        link.sourceNote = source
        link.targetNote = target
        link.type = type
        link.label = label
        return link
    }
}
