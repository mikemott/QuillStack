//
//  NoteLinkServiceTests.swift
//  QuillStackTests
//
//  Created on 2026-01-06.
//  QUI-136: Cross-Note Linking & Knowledge Graph
//

import XCTest
import CoreData
@testable import QuillStack

final class NoteLinkServiceTests: XCTestCase {

    var service: NoteLinkService!
    var context: NSManagedObjectContext!
    var testNote1: Note!
    var testNote2: Note!
    var testNote3: Note!

    override func setUp() {
        super.setUp()
        service = NoteLinkService.shared
        context = CoreDataStack.preview.context

        // Create test notes
        testNote1 = Note.create(in: context, content: "Test Note 1", noteType: "general")
        testNote2 = Note.create(in: context, content: "Test Note 2", noteType: "todo")
        testNote3 = Note.create(in: context, content: "Test Note 3", noteType: "meeting")

        try? context.save()
    }

    override func tearDown() {
        // Clean up test data
        if let notes = try? context.fetch(Note.fetchRequest()) as? [Note] {
            notes.forEach { context.delete($0) }
        }
        if let links = try? context.fetch(NoteLink.fetchRequest()) as? [NoteLink] {
            links.forEach { context.delete($0) }
        }
        try? context.save()

        testNote1 = nil
        testNote2 = nil
        testNote3 = nil
        context = nil
        service = nil
        super.tearDown()
    }

    // MARK: - Link Creation Tests

    func testCreateBasicLink() throws {
        let link = try service.createLink(from: testNote1, to: testNote2, in: context)

        XCTAssertNotNil(link)
        XCTAssertEqual(link.sourceNote.id, testNote1.id)
        XCTAssertEqual(link.targetNote.id, testNote2.id)
        XCTAssertEqual(link.type, .reference)
    }

    func testCreateLinkWithCustomType() throws {
        let link = try service.createLink(from: testNote1, to: testNote2, type: .parent, in: context)

        XCTAssertEqual(link.type, .parent)
    }

    func testCreateLinkWithLabel() throws {
        let link = try service.createLink(from: testNote1, to: testNote2, label: "Custom Label", in: context)

        XCTAssertEqual(link.label, "Custom Label")
        XCTAssertEqual(link.displayLabel, "Custom Label")
    }

    func testCreateMultipleLinks() throws {
        let links = try service.createLinks(from: testNote1, to: [testNote2, testNote3], in: context)

        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(testNote1.typedOutgoingLinks.count, 2)
    }

    // MARK: - Validation Tests

    func testPreventSelfLink() {
        XCTAssertThrowsError(try service.createLink(from: testNote1, to: testNote1, in: context)) { error in
            XCTAssertTrue(error is NoteLinkError)
            XCTAssertEqual(error as? NoteLinkError, .selfLink)
        }
    }

    func testPreventDuplicateLink() throws {
        // Create first link
        _ = try service.createLink(from: testNote1, to: testNote2, type: .reference, in: context)

        // Try to create duplicate
        XCTAssertThrowsError(try service.createLink(from: testNote1, to: testNote2, type: .reference, in: context)) { error in
            XCTAssertTrue(error is NoteLinkError)
            XCTAssertEqual(error as? NoteLinkError, .duplicateLink)
        }
    }

    func testAllowDifferentLinkTypes() throws {
        // Create reference link
        _ = try service.createLink(from: testNote1, to: testNote2, type: .reference, in: context)

        // Create related link - should succeed
        let link2 = try service.createLink(from: testNote1, to: testNote2, type: .related, in: context)

        XCTAssertNotNil(link2)
        XCTAssertEqual(testNote1.typedOutgoingLinks.count, 2)
    }

    // MARK: - Cycle Detection Tests

    func testPreventSimpleCycle() throws {
        // Create: Note1 -> Note2 (parent link)
        _ = try service.createLink(from: testNote1, to: testNote2, type: .parent, in: context)

        // Try to create: Note2 -> Note1 (parent link) - should fail (would create cycle)
        XCTAssertThrowsError(try service.createLink(from: testNote2, to: testNote1, type: .parent, in: context)) { error in
            XCTAssertTrue(error is NoteLinkError)
            XCTAssertEqual(error as? NoteLinkError, .cycleDetected)
        }
    }

    func testPreventComplexCycle() throws {
        // Create chain: Note1 -> Note2 -> Note3 (parent links)
        _ = try service.createLink(from: testNote1, to: testNote2, type: .parent, in: context)
        _ = try service.createLink(from: testNote2, to: testNote3, type: .parent, in: context)

        // Try to create: Note3 -> Note1 (parent link) - should fail (would create cycle)
        XCTAssertThrowsError(try service.createLink(from: testNote3, to: testNote1, type: .parent, in: context)) { error in
            XCTAssertTrue(error is NoteLinkError)
            XCTAssertEqual(error as? NoteLinkError, .cycleDetected)
        }
    }

    func testAllowNonCyclicLinks() throws {
        // Create: Note1 -> Note2 (parent)
        _ = try service.createLink(from: testNote1, to: testNote2, type: .parent, in: context)

        // Create: Note1 -> Note3 (parent) - should succeed (no cycle)
        let link = try service.createLink(from: testNote1, to: testNote3, type: .parent, in: context)

        XCTAssertNotNil(link)
    }

    // MARK: - Link Deletion Tests

    func testDeleteSingleLink() throws {
        let link = try service.createLink(from: testNote1, to: testNote2, in: context)

        service.deleteLink(link, in: context)
        try context.save()

        XCTAssertEqual(testNote1.typedOutgoingLinks.count, 0)
        XCTAssertEqual(testNote2.typedIncomingLinks.count, 0)
    }

    func testDeleteAllLinksBetweenNotes() throws {
        // Create multiple links between same notes
        _ = try service.createLink(from: testNote1, to: testNote2, type: .reference, in: context)
        _ = try service.createLink(from: testNote1, to: testNote2, type: .related, in: context)

        service.deleteAllLinks(from: testNote1, to: testNote2, in: context)
        try context.save()

        XCTAssertEqual(testNote1.typedOutgoingLinks.count, 0)
        XCTAssertEqual(testNote2.typedIncomingLinks.count, 0)
    }

    func testDeleteAllLinksForNote() throws {
        // Create links from testNote1
        _ = try service.createLink(from: testNote1, to: testNote2, in: context)
        _ = try service.createLink(from: testNote1, to: testNote3, in: context)

        // Create links to testNote1
        _ = try service.createLink(from: testNote2, to: testNote1, in: context)

        service.deleteAllLinks(for: testNote1, in: context)
        try context.save()

        XCTAssertEqual(testNote1.typedOutgoingLinks.count, 0)
        XCTAssertEqual(testNote1.typedIncomingLinks.count, 0)
        // testNote2 should still have its link to testNote3
        XCTAssertEqual(testNote2.typedOutgoingLinks.count, 0) // The link to testNote1 was deleted
    }

    // MARK: - Link Query Tests

    func testGetLinksFrom() throws {
        _ = try service.createLink(from: testNote1, to: testNote2, in: context)
        _ = try service.createLink(from: testNote1, to: testNote3, in: context)

        let links = service.getLinks(from: testNote1, in: context)

        XCTAssertEqual(links.count, 2)
    }

    func testGetBacklinks() throws {
        _ = try service.createLink(from: testNote1, to: testNote3, in: context)
        _ = try service.createLink(from: testNote2, to: testNote3, in: context)

        let backlinks = service.getBacklinks(for: testNote3, in: context)

        XCTAssertEqual(backlinks.count, 2)
    }

    func testGetLinkedNotes() throws {
        _ = try service.createLink(from: testNote1, to: testNote2, in: context)
        _ = try service.createLink(from: testNote1, to: testNote3, in: context)

        let linkedNotes = service.getLinkedNotes(from: testNote1, in: context)

        XCTAssertEqual(linkedNotes.count, 2)
        XCTAssertTrue(linkedNotes.contains { $0.id == testNote2.id })
        XCTAssertTrue(linkedNotes.contains { $0.id == testNote3.id })
    }

    func testGetBacklinkNotes() throws {
        _ = try service.createLink(from: testNote1, to: testNote3, in: context)
        _ = try service.createLink(from: testNote2, to: testNote3, in: context)

        let backlinkNotes = service.getBacklinkNotes(for: testNote3, in: context)

        XCTAssertEqual(backlinkNotes.count, 2)
        XCTAssertTrue(backlinkNotes.contains { $0.id == testNote1.id })
        XCTAssertTrue(backlinkNotes.contains { $0.id == testNote2.id })
    }

    // MARK: - Note Extension Tests

    func testForwardLinksProperty() throws {
        _ = try service.createLink(from: testNote1, to: testNote2, in: context)
        _ = try service.createLink(from: testNote1, to: testNote3, in: context)

        XCTAssertEqual(testNote1.forwardLinks.count, 2)
    }

    func testBacklinksProperty() throws {
        _ = try service.createLink(from: testNote1, to: testNote3, in: context)
        _ = try service.createLink(from: testNote2, to: testNote3, in: context)

        XCTAssertEqual(testNote3.backlinks.count, 2)
    }

    func testAllLinkedNotesProperty() throws {
        // Create outgoing link
        _ = try service.createLink(from: testNote1, to: testNote2, in: context)

        // Create incoming link
        _ = try service.createLink(from: testNote3, to: testNote1, in: context)

        let allLinked = testNote1.allLinkedNotes

        XCTAssertEqual(allLinked.count, 2)
        XCTAssertTrue(allLinked.contains { $0.id == testNote2.id })
        XCTAssertTrue(allLinked.contains { $0.id == testNote3.id })
    }

    func testLinkCountProperty() throws {
        _ = try service.createLink(from: testNote1, to: testNote2, in: context)
        _ = try service.createLink(from: testNote3, to: testNote1, in: context)

        XCTAssertEqual(testNote1.linkCount, 2)
    }

    // MARK: - Link Type Tests

    func testLinkTypeDescription() {
        XCTAssertEqual(LinkType.reference.description, "References")
        XCTAssertEqual(LinkType.parent.description, "Parent")
        XCTAssertEqual(LinkType.child.description, "Child")
        XCTAssertEqual(LinkType.related.description, "Related to")
        XCTAssertEqual(LinkType.duplicate.description, "Duplicate of")
        XCTAssertEqual(LinkType.implements.description, "Implements")
        XCTAssertEqual(LinkType.continues.description, "Continues")
    }

    func testLinkTypeIcon() {
        XCTAssertEqual(LinkType.reference.icon, "arrow.right")
        XCTAssertEqual(LinkType.parent.icon, "arrow.up")
        XCTAssertEqual(LinkType.child.icon, "arrow.down")
        XCTAssertEqual(LinkType.related.icon, "arrow.left.arrow.right")
    }

    func testBidirectionalLinkCheck() throws {
        let referenceLink = try service.createLink(from: testNote1, to: testNote2, type: .reference, in: context)
        let relatedLink = try service.createLink(from: testNote1, to: testNote3, type: .related, in: context)

        XCTAssertFalse(referenceLink.isBidirectional)
        XCTAssertTrue(relatedLink.isBidirectional)
    }

    // MARK: - Statistics Tests

    func testGetLinkStatistics() throws {
        _ = try service.createLink(from: testNote1, to: testNote2, type: .reference, in: context)
        _ = try service.createLink(from: testNote1, to: testNote3, type: .reference, in: context)
        _ = try service.createLink(from: testNote2, to: testNote1, type: .related, in: context)

        let stats = service.getLinkStatistics(for: testNote1, in: context)

        XCTAssertEqual(stats[.reference], 2)
        XCTAssertEqual(stats[.related], 1)
    }

    // MARK: - Link Existence Tests

    func testLinkExists() throws {
        _ = try service.createLink(from: testNote1, to: testNote2, type: .reference, in: context)

        XCTAssertTrue(service.linkExists(from: testNote1, to: testNote2, type: .reference, in: context))
        XCTAssertFalse(service.linkExists(from: testNote1, to: testNote2, type: .parent, in: context))
        XCTAssertFalse(service.linkExists(from: testNote2, to: testNote1, type: .reference, in: context))
    }
}

// MARK: - NoteLink Fetch Request Extension

extension NoteLink {
    @objc class func fetchRequest() -> NSFetchRequest<NoteLink> {
        return NSFetchRequest<NoteLink>(entityName: "NoteLink")
    }
}
