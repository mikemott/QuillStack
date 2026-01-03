//
//  TextClassifierTests.swift
//  QuillStackTests
//
//  Created on 2025-12-31.
//

import XCTest
@testable import QuillStack

final class TextClassifierTests: XCTestCase {

    var classifier: TextClassifier!

    override func setUp() {
        super.setUp()
        classifier = TextClassifier()
    }

    override func tearDown() {
        classifier = nil
        super.tearDown()
    }

    // MARK: - Exact Trigger Matching Tests

    func testExactTodoTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#todo# Buy groceries"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "#to-do# Complete report"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "#tasks# Morning routine"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "#task# Call mom"), .todo)
    }

    func testExactEmailTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#email# Dear John"), .email)
        XCTAssertEqual(classifier.classifyNote(content: "#mail# Subject: Meeting"), .email)
    }

    func testExactMeetingTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#meeting# Standup notes"), .meeting)
        XCTAssertEqual(classifier.classifyNote(content: "#notes# Team discussion"), .meeting)
        XCTAssertEqual(classifier.classifyNote(content: "#minutes# Project sync"), .meeting)
    }

    func testExactReminderTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#reminder# Call dentist at 3pm"), .reminder)
        XCTAssertEqual(classifier.classifyNote(content: "#remind# Pick up package"), .reminder)
        XCTAssertEqual(classifier.classifyNote(content: "#remindme# Water plants"), .reminder)
    }

    func testExactContactTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#contact# John Smith 555-1234"), .contact)
        XCTAssertEqual(classifier.classifyNote(content: "#person# Jane Doe"), .contact)
        XCTAssertEqual(classifier.classifyNote(content: "#phone# Mike 555-9876"), .contact)
    }

    func testExactExpenseTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#expense# Coffee $5.50"), .expense)
        XCTAssertEqual(classifier.classifyNote(content: "#receipt# Walmart $42.00"), .expense)
        XCTAssertEqual(classifier.classifyNote(content: "#spent# Lunch $12"), .expense)
        XCTAssertEqual(classifier.classifyNote(content: "#paid# Electric bill $80"), .expense)
    }

    func testExactShoppingTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#shopping# Milk, eggs, bread"), .shopping)
        XCTAssertEqual(classifier.classifyNote(content: "#shop# New shoes"), .shopping)
        XCTAssertEqual(classifier.classifyNote(content: "#grocery# Weekly groceries"), .shopping)
        XCTAssertEqual(classifier.classifyNote(content: "#groceries# For the party"), .shopping)
        XCTAssertEqual(classifier.classifyNote(content: "#list# Party supplies"), .shopping)
    }

    func testExactRecipeTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#recipe# Chocolate cake"), .recipe)
        XCTAssertEqual(classifier.classifyNote(content: "#cook# Pasta carbonara"), .recipe)
        XCTAssertEqual(classifier.classifyNote(content: "#bake# Banana bread"), .recipe)
    }

    func testExactEventTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#event# Birthday party tomorrow"), .event)
        XCTAssertEqual(classifier.classifyNote(content: "#appointment# Doctor visit 2pm"), .event)
        XCTAssertEqual(classifier.classifyNote(content: "#schedule# Team offsite next week"), .event)
        XCTAssertEqual(classifier.classifyNote(content: "#appt# Dentist Friday"), .event)
    }

    func testExactIdeaTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#idea# App for tracking water"), .idea)
        XCTAssertEqual(classifier.classifyNote(content: "#thought# Maybe we should..."), .idea)
        XCTAssertEqual(classifier.classifyNote(content: "#note-to-self# Remember this"), .idea)
        XCTAssertEqual(classifier.classifyNote(content: "#notetoself# Future project"), .idea)
    }

    func testExactClaudePromptTriggers() {
        XCTAssertEqual(classifier.classifyNote(content: "#claude# Help me write tests"), .claudePrompt)
        XCTAssertEqual(classifier.classifyNote(content: "#feature# Add dark mode"), .claudePrompt)
        XCTAssertEqual(classifier.classifyNote(content: "#prompt# Generate code for..."), .claudePrompt)
        XCTAssertEqual(classifier.classifyNote(content: "#request# Please implement..."), .claudePrompt)
        XCTAssertEqual(classifier.classifyNote(content: "#issue# Bug in login flow"), .claudePrompt)
    }

    // MARK: - Case Insensitivity Tests

    func testCaseInsensitivity() {
        XCTAssertEqual(classifier.classifyNote(content: "#TODO# Buy groceries"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "#Todo# Buy groceries"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "#EMAIL# Dear John"), .email)
        XCTAssertEqual(classifier.classifyNote(content: "#REMINDER# Call mom"), .reminder)
    }

    // MARK: - Fuzzy OCR Matching Tests

    func testFuzzyTodoMatching() {
        XCTAssertEqual(classifier.classifyNote(content: "#tod0# Buy groceries"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "#todoo# Complete report"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "#taskk# Morning routine"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "#tashs# Multiple tasks"), .todo)
    }

    func testFuzzyEmailMatching() {
        XCTAssertEqual(classifier.classifyNote(content: "#emaill# Dear John"), .email)
        XCTAssertEqual(classifier.classifyNote(content: "#ernail# OCR error"), .email)
        XCTAssertEqual(classifier.classifyNote(content: "#emai1# Number one"), .email)
        XCTAssertEqual(classifier.classifyNote(content: "#mai1# Also number one"), .email)
    }

    func testFuzzyReminderMatching() {
        XCTAssertEqual(classifier.classifyNote(content: "#reminde# Missing r"), .reminder)
        XCTAssertEqual(classifier.classifyNote(content: "#rerinder# Wrong r"), .reminder)
        XCTAssertEqual(classifier.classifyNote(content: "#rerninder# m as rn"), .reminder)
    }

    func testFuzzyExpenseMatching() {
        XCTAssertEqual(classifier.classifyNote(content: "#expens3# Number for e"), .expense)
        XCTAssertEqual(classifier.classifyNote(content: "#recipt# Missing e"), .expense)
        XCTAssertEqual(classifier.classifyNote(content: "#reciept# Swapped ie"), .expense)
    }

    func testFuzzyMeetingMatching() {
        XCTAssertEqual(classifier.classifyNote(content: "#meetinq# g as q"), .meeting)
        XCTAssertEqual(classifier.classifyNote(content: "#rneetinq# m as rn and g as q"), .meeting)
    }

    // MARK: - Edge Cases

    func testEmptyString() {
        XCTAssertEqual(classifier.classifyNote(content: ""), .general)
    }

    func testNoHashtag() {
        XCTAssertEqual(classifier.classifyNote(content: "Just some regular text"), .general)
    }

    func testHashtagWithoutType() {
        XCTAssertEqual(classifier.classifyNote(content: "#unknown# Something"), .general)
    }

    func testMultipleHashtags() {
        // First matching hashtag wins
        XCTAssertEqual(classifier.classifyNote(content: "#todo# Buy groceries #email# Send later"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "#email# #todo# Mixed"), .email)
    }

    func testHashtagInMiddle() {
        // Should still detect trigger in first ~100 chars
        let content = "Some intro text #todo# Buy groceries"
        XCTAssertEqual(classifier.classifyNote(content: content), .todo)
    }

    func testHashtagAfter100Chars() {
        // Should NOT detect trigger after first 100 chars
        let longPrefix = String(repeating: "a", count: 101)
        let content = longPrefix + "#todo# Buy groceries"
        XCTAssertEqual(classifier.classifyNote(content: content), .general)
    }

    func testWhitespaceAroundTrigger() {
        XCTAssertEqual(classifier.classifyNote(content: "  #todo#  Buy groceries"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "\n#email#\nDear John"), .email)
    }

    // MARK: - Content Analysis Fallback Tests

    func testMeetingContentAnalysis() {
        XCTAssertEqual(classifier.classifyNote(content: "Meeting with John at 3pm"), .meeting)
        XCTAssertEqual(classifier.classifyNote(content: "Call with client about project"), .meeting)
        XCTAssertEqual(classifier.classifyNote(content: "Agenda:\n1. Review\n2. Plan"), .meeting)
        XCTAssertEqual(classifier.classifyNote(content: "Attendees: John, Jane, Mike"), .meeting)
        XCTAssertEqual(classifier.classifyNote(content: "Action items from today"), .meeting)
    }

    func testTodoContentAnalysis() {
        XCTAssertEqual(classifier.classifyNote(content: "[ ] Buy groceries\n[ ] Clean room"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "[x] Done task\n[ ] Pending task"), .todo)
        XCTAssertEqual(classifier.classifyNote(content: "Checklist for tomorrow"), .todo)
    }

    // MARK: - Voice Command Detection

    func testVoiceCommandReminderDetection() {
        let content = "I'd like to create a reminder for tomorrow at 2pm to pay bills."
        XCTAssertEqual(classifier.classifyNote(content: content), .reminder)
    }

    func testVoiceCommandTodoDetection() {
        let content = "Please add this to my to-do list: call the contractor about the leak."
        XCTAssertEqual(classifier.classifyNote(content: content), .todo)
    }

    func testVoiceCommandMeetingDetection() {
        let content = "Let's schedule a meeting with Ben on Tuesday to go over integrations."
        XCTAssertEqual(classifier.classifyNote(content: content), .meeting)
    }

    // MARK: - extractTriggerTag Tests

    func testExtractTriggerTagBasic() {
        let result = classifier.extractTriggerTag(from: "#todo# Buy groceries")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.tag, "#todo#")
        XCTAssertEqual(result?.cleanedContent, "Buy groceries")
    }

    func testExtractTriggerTagPreservesCase() {
        let result = classifier.extractTriggerTag(from: "#TODO# Buy groceries")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.tag, "#TODO#")
        XCTAssertEqual(result?.cleanedContent, "Buy groceries")
    }

    func testExtractTriggerTagWithNewlines() {
        let result = classifier.extractTriggerTag(from: "#email#\nDear John,\nHow are you?")
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.tag, "#email#")
        XCTAssertEqual(result?.cleanedContent, "Dear John,\nHow are you?")
    }

    func testExtractTriggerTagNoMatch() {
        let result = classifier.extractTriggerTag(from: "Just regular text")
        XCTAssertNil(result)
    }

    func testExtractTriggerTagUnknownType() {
        let result = classifier.extractTriggerTag(from: "#unknown# Some content")
        XCTAssertNil(result)
    }

    // MARK: - extractAllTriggerTags Tests

    func testExtractAllTriggerTagsTodo() {
        let content = "#todo# Task 1\n#task# Task 2\n#tasks# Task 3"
        let cleaned = classifier.extractAllTriggerTags(from: content, for: .todo)
        XCTAssertFalse(cleaned.contains("#todo#"))
        XCTAssertFalse(cleaned.contains("#task#"))
        XCTAssertFalse(cleaned.contains("#tasks#"))
        XCTAssertTrue(cleaned.contains("Task 1"))
        XCTAssertTrue(cleaned.contains("Task 2"))
        XCTAssertTrue(cleaned.contains("Task 3"))
    }

    func testExtractAllTriggerTagsCaseInsensitive() {
        let content = "#TODO# Task 1\n#Todo# Task 2"
        let cleaned = classifier.extractAllTriggerTags(from: content, for: .todo)
        XCTAssertFalse(cleaned.contains("#TODO#"))
        XCTAssertFalse(cleaned.contains("#Todo#"))
    }

    func testExtractAllTriggerTagsGeneral() {
        let content = "Some general content"
        let cleaned = classifier.extractAllTriggerTags(from: content, for: .general)
        XCTAssertEqual(cleaned, content)
    }

    func testExtractAllTriggerTagsCleansWhitespace() {
        let content = "#todo#   \n\n\n   Task 1"
        let cleaned = classifier.extractAllTriggerTags(from: content, for: .todo)
        // Should not have excessive newlines
        XCTAssertFalse(cleaned.contains("\n\n\n"))
    }

    // MARK: - All Note Types Classification

    func testAllNoteTypesClassification() {
        let testCases: [(String, NoteType)] = [
            ("#todo# Task", .todo),
            ("#email# Dear", .email),
            ("#meeting# Notes", .meeting),
            ("#reminder# Call", .reminder),
            ("#contact# John", .contact),
            ("#expense# $50", .expense),
            ("#shopping# Milk", .shopping),
            ("#recipe# Cake", .recipe),
            ("#event# Party", .event),
            ("#idea# App", .idea),
            ("#claude# Help", .claudePrompt),
            ("General note", .general)
        ]

        for (content, expectedType) in testCases {
            XCTAssertEqual(
                classifier.classifyNote(content: content),
                expectedType,
                "Failed for content: \(content)"
            )
        }
    }

    // MARK: - Multi-Tag Splitting Tests

    func testSplitIntoSections_SingleTag() {
        let content = "#todo# Buy milk"
        let sections = classifier.splitIntoSections(content: content)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].noteType, .todo)
        XCTAssertEqual(sections[0].content, "Buy milk")
    }

    func testSplitIntoSections_MultipleTags() {
        let content = """
        #todo# Buy groceries
        Get milk and bread

        #email# Draft response to client
        Dear Jane, Thank you for your inquiry.
        """

        let sections = classifier.splitIntoSections(content: content)

        XCTAssertEqual(sections.count, 2)

        XCTAssertEqual(sections[0].noteType, .todo)
        XCTAssertTrue(sections[0].content.contains("Buy groceries"))
        XCTAssertTrue(sections[0].content.contains("Get milk and bread"))

        XCTAssertEqual(sections[1].noteType, .email)
        XCTAssertTrue(sections[1].content.contains("Draft response"))
        XCTAssertTrue(sections[1].content.contains("Dear Jane"))
    }

    func testSplitIntoSections_ThreeTags() {
        let content = """
        #todo# Call dentist

        #shopping# Milk, eggs, butter

        #reminder# Pick up package at 3pm
        """

        let sections = classifier.splitIntoSections(content: content)

        XCTAssertEqual(sections.count, 3)
        XCTAssertEqual(sections[0].noteType, .todo)
        XCTAssertEqual(sections[1].noteType, .shopping)
        XCTAssertEqual(sections[2].noteType, .reminder)
    }

    func testSplitIntoSections_ContentBeforeFirstTag() {
        let content = """
        Some notes before the tag

        #todo# Buy milk
        """

        let sections = classifier.splitIntoSections(content: content)

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].noteType, .general)
        XCTAssertTrue(sections[0].content.contains("Some notes before"))

        XCTAssertEqual(sections[1].noteType, .todo)
        XCTAssertTrue(sections[1].content.contains("Buy milk"))
    }

    func testSplitIntoSections_NoTags() {
        let content = "Just some general content without tags"
        let sections = classifier.splitIntoSections(content: content)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].noteType, .general)
        XCTAssertEqual(sections[0].content, content)
    }

    func testSplitIntoSections_EmptyContentBetweenTags() {
        let content = "#todo##email# Draft"

        let sections = classifier.splitIntoSections(content: content)

        // Should only create one section for #email# since #todo# has no content
        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections[0].noteType, .email)
    }

    func testSplitIntoSections_MixedCaseAndWhitespace() {
        let content = """
        #TODO#    Buy groceries


        #Email#   Dear John
        """

        let sections = classifier.splitIntoSections(content: content)

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].noteType, .todo)
        XCTAssertEqual(sections[1].noteType, .email)
    }
}
