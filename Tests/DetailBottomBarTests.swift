//
//  DetailBottomBarTests.swift
//  QuillStackTests
//
//  Tests for the DetailBottomBar component and related types.
//

import XCTest
@testable import QuillStack

final class DetailBottomBarTests: XCTestCase {

    // MARK: - DetailAction Tests

    func testDetailActionIconOnly() {
        var actionCalled = false
        let action = DetailAction(icon: "star", color: .blue) {
            actionCalled = true
        }

        XCTAssertEqual(action.icon, "star")
        XCTAssertNil(action.label)
        XCTAssertNotNil(action.id)

        action.action()
        XCTAssertTrue(actionCalled)
    }

    func testDetailActionWithLabel() {
        var actionCalled = false
        let action = DetailAction(
            icon: "bell.badge",
            label: "Add to Reminders",
            color: .orange
        ) {
            actionCalled = true
        }

        XCTAssertEqual(action.icon, "bell.badge")
        XCTAssertEqual(action.label, "Add to Reminders")
        XCTAssertNotNil(action.id)

        action.action()
        XCTAssertTrue(actionCalled)
    }

    func testDetailActionUniqueIds() {
        let action1 = DetailAction(icon: "star", color: .blue) {}
        let action2 = DetailAction(icon: "star", color: .blue) {}

        XCTAssertNotEqual(action1.id, action2.id)
    }

    // MARK: - AIAction Tests

    func testAIActionCreation() {
        var actionCalled = false
        let aiAction = AIAction(icon: "wand.and.stars", label: "Enhance") {
            actionCalled = true
        }

        XCTAssertEqual(aiAction.icon, "wand.and.stars")
        XCTAssertEqual(aiAction.label, "Enhance")
        XCTAssertNotNil(aiAction.id)

        aiAction.action()
        XCTAssertTrue(actionCalled)
    }

    func testAIActionUniqueIds() {
        let action1 = AIAction(icon: "sparkles", label: "AI 1") {}
        let action2 = AIAction(icon: "sparkles", label: "AI 2") {}

        XCTAssertNotEqual(action1.id, action2.id)
    }

    // MARK: - Standard AI Actions Tests

    func testStandardAIActions() {
        var enhanceCalled = false
        var summarizeCalled = false

        let actions = DetailBottomBar.standardAIActions(
            onEnhance: { enhanceCalled = true },
            onSummarize: { summarizeCalled = true }
        )

        XCTAssertEqual(actions.count, 2)
        XCTAssertEqual(actions[0].label, "Enhance Text")
        XCTAssertEqual(actions[1].label, "Summarize")

        actions[0].action()
        XCTAssertTrue(enhanceCalled)

        actions[1].action()
        XCTAssertTrue(summarizeCalled)
    }

    func testSummarizeOnlyAIActions() {
        var summarizeCalled = false

        let actions = DetailBottomBar.summarizeOnlyAIActions(
            onSummarize: { summarizeCalled = true }
        )

        XCTAssertEqual(actions.count, 1)
        XCTAssertEqual(actions[0].label, "Summarize")

        actions[0].action()
        XCTAssertTrue(summarizeCalled)
    }
}
