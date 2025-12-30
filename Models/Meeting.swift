//
//  Meeting.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import CoreData

@objc(Meeting)
public class Meeting: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var title: String
    @NSManaged public var meetingDate: Date?
    @NSManaged public var duration: Int16 // In minutes
    @NSManaged public var attendees: String? // Comma-separated attendees
    @NSManaged public var agenda: String?
    @NSManaged public var actionItems: String? // Newline-separated action items
    @NSManaged public var createdAt: Date
    @NSManaged public var calendarEventIdentifier: String? // Links to EKEvent

    // Relationship
    @NSManaged public var note: Note?

    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        duration = 60 // Default 1 hour
    }
}

// MARK: - Convenience Properties
extension Meeting {
    var attendeesList: [String] {
        attendees?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
    }

    var actionItemsList: [String] {
        actionItems?.components(separatedBy: "\n").filter { !$0.isEmpty } ?? []
    }
}

// MARK: - Convenience Initializer
extension Meeting {
    static func create(
        in context: NSManagedObjectContext,
        title: String,
        date: Date? = nil,
        attendees: [String] = [],
        note: Note? = nil
    ) -> Meeting {
        let meeting = Meeting(context: context)
        meeting.title = title
        meeting.meetingDate = date
        meeting.attendees = attendees.joined(separator: ", ")
        meeting.note = note
        return meeting
    }
}
