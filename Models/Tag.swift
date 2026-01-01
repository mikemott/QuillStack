//
//  Tag.swift
//  QuillStack
//
//  Phase 4.3 - Architecture refactoring: structured tag entity.
//  Replaces comma-separated tag strings with proper Core Data relationships.
//

import Foundation
import CoreData
import SwiftUI

@objc(Tag)
public class Tag: NSManagedObject, Identifiable {

    // MARK: - Core Data Attributes

    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var color: String?
    @NSManaged public var createdAt: Date

    // MARK: - Relationships

    @NSManaged public var notes: Set<Note>

    // MARK: - Computed Properties

    /// Number of notes with this tag
    var noteCount: Int {
        notes.count
    }

    /// SwiftUI Color from hex string
    var displayColor: Color {
        guard let hex = color else { return .gray }
        return Color(hex: hex) ?? .gray
    }

    /// Whether this tag is applied to any notes
    var isUsed: Bool {
        !notes.isEmpty
    }

    // MARK: - Lifecycle

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
    }
}

// MARK: - Fetch Requests

extension Tag {
    /// Fetch request for all tags sorted by name
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        NSFetchRequest<Tag>(entityName: "Tag")
    }

    /// Fetch request for tags sorted by name
    static func sortedFetchRequest() -> NSFetchRequest<Tag> {
        let request = fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        return request
    }

    /// Fetch request for tags sorted by usage (most used first)
    static func byUsageFetchRequest() -> NSFetchRequest<Tag> {
        let request = fetchRequest()
        // Note: Can't sort by relationship count directly in fetch request
        // Sort by name as fallback, then re-sort in memory if needed
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.name, ascending: true)]
        return request
    }

    /// Find a tag by name
    static func find(name: String, in context: NSManagedObjectContext) -> Tag? {
        let request = fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    /// Find or create a tag by name
    static func findOrCreate(
        name: String,
        in context: NSManagedObjectContext
    ) -> Tag {
        if let existing = find(name: name, in: context) {
            return existing
        }

        let tag = Tag(context: context)
        tag.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return tag
    }
}

// MARK: - Convenience Initializer

extension Tag {
    /// Create a new tag
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        color: String? = nil
    ) -> Tag {
        let tag = Tag(context: context)
        tag.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        tag.color = color
        return tag
    }
}

// MARK: - Notes Relationship

extension Tag {
    @objc(addNotesObject:)
    @NSManaged public func addToNotes(_ value: Note)

    @objc(removeNotesObject:)
    @NSManaged public func removeFromNotes(_ value: Note)

    @objc(addNotes:)
    @NSManaged public func addToNotes(_ values: Set<Note>)

    @objc(removeNotes:)
    @NSManaged public func removeFromNotes(_ values: Set<Note>)
}

// MARK: - Note Extension for Tag Entities

extension Note {
    /// Relationship to Tag entities
    @NSManaged public var tagEntities: Set<Tag>?

    /// Get sorted tag entities
    var sortedTagEntities: [Tag] {
        guard let tags = tagEntities else { return [] }
        return tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Tag names from tag entities
    var tagEntityNames: [String] {
        sortedTagEntities.map { $0.name }
    }

    /// Check if note has a specific tag entity
    func hasTagEntity(named name: String) -> Bool {
        tagEntities?.contains { $0.name.lowercased() == name.lowercased() } ?? false
    }

    /// Add a tag entity by name (finds or creates)
    func addTagEntity(named name: String, in context: NSManagedObjectContext) {
        let tag = Tag.findOrCreate(name: name, in: context)
        addToTagEntities(tag)
    }

    /// Remove a tag entity by name
    func removeTagEntity(named name: String) {
        guard let tag = tagEntities?.first(where: { $0.name.lowercased() == name.lowercased() }) else {
            return
        }
        removeFromTagEntities(tag)
    }
}

// MARK: - Tag Entities Relationship Accessors

extension Note {
    @objc(addTagEntitiesObject:)
    @NSManaged public func addToTagEntities(_ value: Tag)

    @objc(removeTagEntitiesObject:)
    @NSManaged public func removeFromTagEntities(_ value: Tag)

    @objc(addTagEntities:)
    @NSManaged public func addToTagEntities(_ values: Set<Tag>)

    @objc(removeTagEntities:)
    @NSManaged public func removeFromTagEntities(_ values: Set<Tag>)
}

// MARK: - Color Helpers

extension Color {
    /// Initialize from hex string (e.g., "#FF5733" or "FF5733")
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        if length == 6 {
            self.init(
                red: Double((rgb & 0xFF0000) >> 16) / 255.0,
                green: Double((rgb & 0x00FF00) >> 8) / 255.0,
                blue: Double(rgb & 0x0000FF) / 255.0
            )
        } else if length == 8 {
            self.init(
                red: Double((rgb & 0xFF000000) >> 24) / 255.0,
                green: Double((rgb & 0x00FF0000) >> 16) / 255.0,
                blue: Double((rgb & 0x0000FF00) >> 8) / 255.0,
                opacity: Double(rgb & 0x000000FF) / 255.0
            )
        } else {
            return nil
        }
    }

    /// Convert color to hex string
    func toHex() -> String? {
        guard let components = UIColor(self).cgColor.components else {
            return nil
        }

        let r = Int(components[0] * 255)
        let g = Int(components.count > 1 ? components[1] * 255 : components[0] * 255)
        let b = Int(components.count > 2 ? components[2] * 255 : components[0] * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Predefined Tag Colors

extension Tag {
    /// Predefined colors for tag selection
    static let predefinedColors: [(name: String, hex: String)] = [
        ("Red", "#E53935"),
        ("Pink", "#D81B60"),
        ("Purple", "#8E24AA"),
        ("Deep Purple", "#5E35B1"),
        ("Indigo", "#3949AB"),
        ("Blue", "#1E88E5"),
        ("Cyan", "#00ACC1"),
        ("Teal", "#00897B"),
        ("Green", "#43A047"),
        ("Light Green", "#7CB342"),
        ("Lime", "#C0CA33"),
        ("Yellow", "#FDD835"),
        ("Amber", "#FFB300"),
        ("Orange", "#FB8C00"),
        ("Deep Orange", "#F4511E"),
        ("Brown", "#6D4C41"),
        ("Gray", "#757575"),
        ("Blue Gray", "#546E7A")
    ]
}
