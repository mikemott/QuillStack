//
//  SmartCollectionServiceTests.swift
//  QuillStackTests
//
//  Created on 2026-01-08.
//  QUI-137: Smart Collections & Saved Searches - Phase 1 Tests
//

import XCTest
import CoreData
@testable import QuillStack

final class SmartCollectionServiceTests: XCTestCase {

    var service: SmartCollectionService!
    var context: NSManagedObjectContext!
    var testNotes: [Note]!

    override func setUp() {
        super.setUp()
        service = SmartCollectionService.shared
        context = CoreDataStack.preview.context

        // Create diverse test notes
        testNotes = createTestNotes()
        try? context.save()
    }

    override func tearDown() {
        // Clean up test data
        if let notes = try? context.fetch(Note.fetchRequest()) as? [Note] {
            notes.forEach { context.delete($0) }
        }
        if let collections = try? context.fetch(SmartCollection.fetchRequest()) as? [SmartCollection] {
            collections.forEach { context.delete($0) }
        }
        try? context.save()

        testNotes = nil
        context = nil
        service = nil
        super.tearDown()
    }

    // MARK: - Test Data Setup

    func createTestNotes() -> [Note] {
        var notes: [Note] = []

        // Recent todo with high confidence
        let todo1 = Note.create(in: context, content: "Buy groceries", noteType: "todo")
        todo1.ocrConfidence = 0.95
        todo1.createdAt = Date().addingTimeInterval(-2 * 24 * 60 * 60) // 2 days ago
        todo1.updatedAt = Date().addingTimeInterval(-1 * 24 * 60 * 60) // 1 day ago
        notes.append(todo1)

        // Old meeting note with low confidence
        let meeting1 = Note.create(in: context, content: "Team standup notes", noteType: "meeting")
        meeting1.ocrConfidence = 0.65
        meeting1.createdAt = Date().addingTimeInterval(-20 * 24 * 60 * 60) // 20 days ago
        meeting1.updatedAt = Date().addingTimeInterval(-20 * 24 * 60 * 60)
        notes.append(meeting1)

        // Recent email with annotations
        let email1 = Note.create(in: context, content: "Client proposal", noteType: "email")
        email1.ocrConfidence = 0.88
        email1.hasAnnotations = true
        email1.createdAt = Date().addingTimeInterval(-5 * 24 * 60 * 60) // 5 days ago
        email1.updatedAt = Date().addingTimeInterval(-3 * 24 * 60 * 60) // 3 days ago
        notes.append(email1)

        // Recipe with tag
        let recipe1 = Note.create(in: context, content: "Chocolate cake recipe", noteType: "recipe")
        recipe1.tags = "dessert,baking"
        recipe1.ocrConfidence = 0.92
        recipe1.createdAt = Date().addingTimeInterval(-10 * 24 * 60 * 60) // 10 days ago
        recipe1.updatedAt = Date().addingTimeInterval(-10 * 24 * 60 * 60)
        notes.append(recipe1)

        // Archived general note
        let general1 = Note.create(in: context, content: "Old notes", noteType: "general")
        general1.isArchived = true
        general1.ocrConfidence = 0.75
        general1.createdAt = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days ago
        general1.updatedAt = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        notes.append(general1)

        return notes
    }

    // MARK: - CRUD Tests

    func testCreateCollection() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .noteType, operator: .equals, value: "todo")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "My Todos",
            query: query
        )

        try service.createCollection(collection, context: context)

        XCTAssertNotNil(collection.id)
        XCTAssertEqual(collection.name, "My Todos")
        XCTAssertNotNil(collection.query)
    }

    func testUpdateCollection() throws {
        let collection = SmartCollection.create(
            in: context,
            name: "Test Collection",
            query: CollectionQuery()
        )
        try service.createCollection(collection, context: context)

        let originalUpdatedAt = collection.updatedAt

        // Wait a bit to ensure timestamp changes
        Thread.sleep(forTimeInterval: 0.1)

        collection.name = "Updated Collection"
        try service.updateCollection(collection, context: context)

        XCTAssertEqual(collection.name, "Updated Collection")
        XCTAssertGreaterThan(collection.updatedAt, originalUpdatedAt)
    }

    func testDeleteCollection() throws {
        let collection = SmartCollection.create(
            in: context,
            name: "Test Collection",
            query: CollectionQuery()
        )
        try service.createCollection(collection, context: context)

        try service.deleteCollection(collection, context: context)

        let fetchRequest = NSFetchRequest<SmartCollection>(entityName: "SmartCollection")
        let count = try context.count(for: fetchRequest)

        XCTAssertEqual(count, 0)
    }

    func testGetAllCollections() throws {
        // Create multiple collections
        for i in 1...3 {
            let collection = SmartCollection.create(
                in: context,
                name: "Collection \(i)",
                query: CollectionQuery()
            )
            collection.order = Int32(i)
            try service.createCollection(collection, context: context)
        }

        let collections = try service.getAllCollections(context: context)
        XCTAssertEqual(collections.count, 3)
    }

    func testGetPinnedCollections() throws {
        // Create pinned and unpinned collections
        let pinned = SmartCollection.create(
            in: context,
            name: "Pinned",
            query: CollectionQuery()
        )
        pinned.isPinned = true
        try service.createCollection(pinned, context: context)

        let unpinned = SmartCollection.create(
            in: context,
            name: "Unpinned",
            query: CollectionQuery()
        )
        try service.createCollection(unpinned, context: context)

        let pinnedCollections = try service.getPinnedCollections(context: context)
        XCTAssertEqual(pinnedCollections.count, 1)
        XCTAssertEqual(pinnedCollections.first?.name, "Pinned")
    }

    // MARK: - Query Evaluation Tests

    func testEvaluateCollectionByNoteType() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .noteType, operator: .equals, value: "todo")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "Todos",
            query: query
        )

        let results = try service.evaluateCollection(collection, context: context)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.noteType, "todo")
    }

    func testEvaluateCollectionByDateRange() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .createdDate, operator: .inLast, value: "7")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "This Week",
            query: query
        )

        let results = try service.evaluateCollection(collection, context: context)

        // Should match notes created in last 7 days (todo1, email1, recipe1)
        XCTAssertGreaterThanOrEqual(results.count, 2)
    }

    func testEvaluateCollectionByConfidence() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .confidence, operator: .lessThan, value: "0.8")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "Low Confidence",
            query: query
        )

        let results = try service.evaluateCollection(collection, context: context)

        // Should match notes with confidence < 0.8 (meeting1, general1)
        XCTAssertGreaterThanOrEqual(results.count, 2)
        for note in results {
            XCTAssertLessThan(note.ocrConfidence, 0.8)
        }
    }

    func testEvaluateCollectionWithMultipleConditionsAND() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .noteType, operator: .equals, value: "todo"),
                QueryCondition(field: .confidence, operator: .greaterThan, value: "0.9")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "High Quality Todos",
            query: query
        )

        let results = try service.evaluateCollection(collection, context: context)

        // Should match only todo1 (type=todo AND confidence>0.9)
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.noteType, "todo")
        XCTAssertGreaterThan(results.first?.ocrConfidence ?? 0, 0.9)
    }

    func testEvaluateCollectionWithMultipleConditionsOR() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .noteType, operator: .equals, value: "todo"),
                QueryCondition(field: .noteType, operator: .equals, value: "meeting")
            ],
            combineWith: .or
        )

        let collection = SmartCollection.create(
            in: context,
            name: "Todos or Meetings",
            query: query
        )

        let results = try service.evaluateCollection(collection, context: context)

        // Should match both todo and meeting notes
        XCTAssertEqual(results.count, 2)
    }

    func testEvaluateCollectionByTag() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .tag, operator: .contains, value: "dessert")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "Desserts",
            query: query
        )

        let results = try service.evaluateCollection(collection, context: context)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.tags?.contains("dessert") ?? false)
    }

    func testEvaluateCollectionByContent() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .content, operator: .contains, value: "recipe")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "Recipes",
            query: query
        )

        let results = try service.evaluateCollection(collection, context: context)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.content.contains("recipe") ?? false)
    }

    func testEvaluateCollectionByArchived() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .isArchived, operator: .equals, value: "true")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "Archived",
            query: query
        )

        let results = try service.evaluateCollection(collection, context: context)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.isArchived ?? false)
    }

    func testEvaluateCollectionByAnnotations() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .hasAnnotations, operator: .equals, value: "true")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "Annotated",
            query: query
        )

        let results = try service.evaluateCollection(collection, context: context)

        XCTAssertEqual(results.count, 1)
        XCTAssertTrue(results.first?.hasAnnotations ?? false)
    }

    func testCountMatchingNotes() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .noteType, operator: .equals, value: "todo")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "Todos",
            query: query
        )

        let count = try service.countMatchingNotes(for: collection, context: context)

        XCTAssertEqual(count, 1)
    }

    // MARK: - Validation Tests

    func testValidateEmptyQuery() {
        let query = CollectionQuery(conditions: [], combineWith: .and)

        XCTAssertThrowsError(try service.validateQuery(query)) { error in
            XCTAssertTrue(error is SmartCollectionError)
        }
    }

    func testValidateValidQuery() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .noteType, operator: .equals, value: "todo")
            ],
            combineWith: .and
        )

        XCTAssertNoThrow(try service.validateQuery(query))
    }

    func testValidateInvalidNumericValue() {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .confidence, operator: .equals, value: "not a number")
            ],
            combineWith: .and
        )

        XCTAssertThrowsError(try service.validateQuery(query))
    }

    func testValidateInvalidOperatorForField() {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .hasAnnotations, operator: .contains, value: "true")
            ],
            combineWith: .and
        )

        XCTAssertThrowsError(try service.validateQuery(query))
    }

    // MARK: - Sort Order Tests

    func testCollectionWithSortOrder() throws {
        let query = CollectionQuery(
            conditions: [
                QueryCondition(field: .createdDate, operator: .inLast, value: "30")
            ],
            combineWith: .and
        )

        let collection = SmartCollection.create(
            in: context,
            name: "Recent Notes",
            query: query,
            sortOrder: .dateNewest
        )

        let results = try service.evaluateCollection(collection, context: context)

        // Verify results are sorted by date (newest first)
        if results.count > 1 {
            XCTAssertGreaterThanOrEqual(results[0].createdAt, results[1].createdAt)
        }
    }
}
