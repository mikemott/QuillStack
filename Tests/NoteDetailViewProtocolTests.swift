//
//  NoteDetailViewProtocolTests.swift
//  QuillStackTests
//
//  Tests for NoteDetailViewProtocol default implementations.
//

import XCTest
import SwiftUI
@testable import QuillStack

// MARK: - Test Helper

/// A minimal conforming view for testing protocol default implementations
private struct TestDetailView: View, NoteDetailViewProtocol {
    var note: Note

    var body: some View {
        Text(note.content)
    }

    func saveChanges() {
        // Test implementation - no-op
    }
}

/// A view with custom shareableContent implementation
private struct CustomShareableView: View, NoteDetailViewProtocol {
    var note: Note
    let customContent: String

    var body: some View {
        Text(note.content)
    }

    func saveChanges() {}

    var shareableContent: String {
        customContent
    }
}

// MARK: - Tests

final class NoteDetailViewProtocolTests: XCTestCase {

    var testNote: Note!

    override func setUp() {
        super.setUp()
        testNote = Note(context: CoreDataStack.shared.viewContext)
        testNote.content = "Test note content"
        testNote.createdAt = Date()
        testNote.updatedAt = Date()
    }

    override func tearDown() {
        CoreDataStack.shared.viewContext.rollback()
        testNote = nil
        super.tearDown()
    }

    // MARK: - Default shareableContent Tests

    func testDefaultShareableContentReturnsNoteContent() {
        let view = TestDetailView(note: testNote)
        XCTAssertEqual(view.shareableContent, "Test note content")
    }

    func testDefaultShareableContentWithEmptyContent() {
        testNote.content = ""
        let view = TestDetailView(note: testNote)
        XCTAssertEqual(view.shareableContent, "")
    }

    func testDefaultShareableContentWithMultilineContent() {
        testNote.content = "Line 1\nLine 2\nLine 3"
        let view = TestDetailView(note: testNote)
        XCTAssertEqual(view.shareableContent, "Line 1\nLine 2\nLine 3")
    }

    // MARK: - Custom shareableContent Tests

    func testCustomShareableContentOverride() {
        let view = CustomShareableView(
            note: testNote,
            customContent: "Custom formatted content"
        )
        XCTAssertEqual(view.shareableContent, "Custom formatted content")
    }

    // MARK: - Protocol Conformance Tests

    func testAllDetailViewsConformToProtocol() {
        // This test verifies at compile time that all detail views conform to the protocol
        // If any view doesn't conform, this test won't compile

        // We can't instantiate these without proper dependencies, but we can verify
        // the types conform to the protocol
        XCTAssertTrue(TodoDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(EmailDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(NoteDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(MeetingDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(ReminderDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(ContactDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(ExpenseDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(ShoppingDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(RecipeDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(EventDetailView.self is any NoteDetailViewProtocol.Type)
        XCTAssertTrue(IdeaDetailView.self is any NoteDetailViewProtocol.Type)
    }
}
