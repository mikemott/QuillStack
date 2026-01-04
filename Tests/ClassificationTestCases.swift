//
//  ClassificationTestCases.swift
//  QuillStack
//
//  Test cases for evaluating LLM classification accuracy
//

import Foundation

/// Test case for classification accuracy testing
struct ClassificationTestCase {
    let id: String
    let text: String
    let expectedType: NoteType
    let category: TestCategory
    let difficulty: Difficulty
    let notes: String?

    enum TestCategory {
        case obvious        // Should be 100% accurate
        case edgeCase      // Challenging cases
        case ambiguous     // Multiple valid interpretations
    }

    enum Difficulty {
        case easy
        case medium
        case hard
    }
}

/// Comprehensive test cases covering all note types
struct ClassificationTestSuite {
    static let allTests: [ClassificationTestCase] = [

        // MARK: - Todo (Easy Cases)

        ClassificationTestCase(
            id: "todo-001",
            text: """
            - Buy groceries
            - Call dentist
            - Finish report
            """,
            expectedType: .todo,
            category: .obvious,
            difficulty: .easy,
            notes: "Clear checklist format"
        ),

        ClassificationTestCase(
            id: "todo-002",
            text: """
            TODO:
            1. Review budget
            2. Send invoices
            3. Update spreadsheet
            """,
            expectedType: .todo,
            category: .obvious,
            difficulty: .easy,
            notes: "Numbered list with TODO label"
        ),

        // MARK: - Quote (Critical Test Cases)

        ClassificationTestCase(
            id: "quote-001",
            text: """
            "The best time to plant a tree was 20 years ago. The second best time is now."
            - Chinese Proverb
            """,
            expectedType: .general, // Note: Currently no .quote type in NoteType
            category: .obvious,
            difficulty: .easy,
            notes: "Classic quote with attribution"
        ),

        ClassificationTestCase(
            id: "quote-002",
            text: """
            "Do or do not. There is no try."
            - Yoda
            """,
            expectedType: .general,
            category: .obvious,
            difficulty: .easy,
            notes: "Famous quote with attribution"
        ),

        ClassificationTestCase(
            id: "quote-003",
            text: """
            Quote from today's meeting:
            "We need to ship by Friday or we'll miss the deadline"
            """,
            expectedType: .meeting,
            category: .edgeCase,
            difficulty: .hard,
            notes: "Should be meeting note, not quote - contains quote but is meeting context"
        ),

        ClassificationTestCase(
            id: "quote-004",
            text: """
            Remember what Sarah said: "Please call me back before 5pm"
            """,
            expectedType: .reminder,
            category: .edgeCase,
            difficulty: .hard,
            notes: "Reminder with quoted text - intent is reminder, not preserving quote"
        ),

        // MARK: - Business Card / Contact

        ClassificationTestCase(
            id: "contact-001",
            text: """
            John Smith
            Senior Developer
            Acme Corp
            john.smith@acme.com
            (555) 123-4567
            """,
            expectedType: .contact,
            category: .obvious,
            difficulty: .easy,
            notes: "Classic business card layout"
        ),

        ClassificationTestCase(
            id: "contact-002",
            text: """
            Sarah Johnson
            sarah.j@example.com
            555-9876
            """,
            expectedType: .contact,
            category: .obvious,
            difficulty: .easy,
            notes: "Minimal contact info"
        ),

        ClassificationTestCase(
            id: "contact-003",
            text: """
            Met Jane at conference
            jane@startup.io
            Wants to discuss partnership
            """,
            expectedType: .contact,
            category: .edgeCase,
            difficulty: .medium,
            notes: "Contact with context - should still be contact"
        ),

        // MARK: - Meeting Notes

        ClassificationTestCase(
            id: "meeting-001",
            text: """
            Meeting with Marketing Team
            Jan 15, 2026 - 2pm

            Attendees: Sarah, Mike, Tom

            Agenda:
            - Q1 campaign review
            - Budget discussion

            Action items:
            - Sarah to send report by Friday
            """,
            expectedType: .meeting,
            category: .obvious,
            difficulty: .easy,
            notes: "Clear meeting structure"
        ),

        ClassificationTestCase(
            id: "meeting-002",
            text: """
            Call with client at 3pm tomorrow
            Discuss project timeline
            Need to review their feedback
            """,
            expectedType: .meeting,
            category: .obvious,
            difficulty: .medium,
            notes: "Informal meeting note"
        ),

        // MARK: - Event / Appointment

        ClassificationTestCase(
            id: "event-001",
            text: """
            Tech Conference 2026
            March 15-17
            San Francisco Convention Center

            Registration: 8am
            Keynote: 9:30am
            """,
            expectedType: .event,
            category: .obvious,
            difficulty: .easy,
            notes: "Event flyer information"
        ),

        ClassificationTestCase(
            id: "event-002",
            text: """
            Doctor appointment
            Thursday 2pm
            City Medical Center
            """,
            expectedType: .event,
            category: .obvious,
            difficulty: .easy,
            notes: "Simple appointment"
        ),

        // MARK: - Email Draft

        ClassificationTestCase(
            id: "email-001",
            text: """
            To: team@company.com
            Subject: Project Update

            Hi Team,

            Quick update on the project status...

            Best,
            Mike
            """,
            expectedType: .email,
            category: .obvious,
            difficulty: .easy,
            notes: "Email with headers"
        ),

        ClassificationTestCase(
            id: "email-002",
            text: """
            Draft email to Sarah:

            Thanks for your help yesterday. Can we schedule a follow-up call?
            """,
            expectedType: .email,
            category: .obvious,
            difficulty: .medium,
            notes: "Informal email draft"
        ),

        // MARK: - Expense / Receipt

        ClassificationTestCase(
            id: "expense-001",
            text: """
            Office Supplies Store
            Jan 4, 2026

            Pens: $12.99
            Notebooks: $24.50
            Stapler: $8.99

            Total: $46.48
            """,
            expectedType: .expense,
            category: .obvious,
            difficulty: .easy,
            notes: "Receipt with itemization"
        ),

        ClassificationTestCase(
            id: "expense-002",
            text: """
            Lunch meeting with client
            $87.50
            Italian Restaurant
            """,
            expectedType: .expense,
            category: .obvious,
            difficulty: .medium,
            notes: "Simple expense note"
        ),

        // MARK: - Shopping List

        ClassificationTestCase(
            id: "shopping-001",
            text: """
            Grocery list:
            - Milk
            - Bread
            - Eggs
            - Apples
            - Chicken
            """,
            expectedType: .shopping,
            category: .obvious,
            difficulty: .easy,
            notes: "Classic shopping list"
        ),

        ClassificationTestCase(
            id: "shopping-002",
            text: """
            Hardware store:
            Screws
            Paint (blue)
            Brushes
            """,
            expectedType: .shopping,
            category: .obvious,
            difficulty: .easy,
            notes: "Non-grocery shopping"
        ),

        // MARK: - Recipe

        ClassificationTestCase(
            id: "recipe-001",
            text: """
            Mom's Chocolate Chip Cookies

            Ingredients:
            - 2 cups flour
            - 1 cup butter
            - 1 cup sugar
            - 2 eggs
            - Chocolate chips

            Bake at 350°F for 12 minutes
            """,
            expectedType: .recipe,
            category: .obvious,
            difficulty: .easy,
            notes: "Recipe with ingredients and instructions"
        ),

        // MARK: - Idea / Brainstorm

        ClassificationTestCase(
            id: "idea-001",
            text: """
            App idea: Collaborative whiteboard with real-time sync

            Features:
            - Multi-user drawing
            - Voice chat
            - Export to PDF

            Could integrate with our existing platform
            """,
            expectedType: .idea,
            category: .obvious,
            difficulty: .medium,
            notes: "Product idea with details"
        ),

        ClassificationTestCase(
            id: "idea-002",
            text: """
            What if we redesigned the homepage with a minimalist approach?
            Focus on three key actions instead of overwhelming new users.
            """,
            expectedType: .idea,
            category: .obvious,
            difficulty: .medium,
            notes: "Design idea"
        ),

        // MARK: - Reminder

        ClassificationTestCase(
            id: "reminder-001",
            text: """
            Remind me to call Mom on Sunday
            """,
            expectedType: .reminder,
            category: .obvious,
            difficulty: .easy,
            notes: "Clear reminder with voice command"
        ),

        ClassificationTestCase(
            id: "reminder-002",
            text: """
            Don't forget:
            - Submit timesheet by Friday
            - Renew parking permit
            """,
            expectedType: .reminder,
            category: .edgeCase,
            difficulty: .medium,
            notes: "Could be todo or reminder - 'don't forget' suggests reminder"
        ),

        // MARK: - Claude Prompt

        ClassificationTestCase(
            id: "claude-001",
            text: """
            @Claude: Help me write a function that validates email addresses in Swift
            Include error handling and unit tests
            """,
            expectedType: .claudePrompt,
            category: .obvious,
            difficulty: .easy,
            notes: "Explicit Claude mention"
        ),

        ClassificationTestCase(
            id: "claude-002",
            text: """
            Write a regex pattern for phone number validation
            Should support US and international formats
            """,
            expectedType: .claudePrompt,
            category: .edgeCase,
            difficulty: .hard,
            notes: "Could be general note or Claude prompt - no explicit mention"
        ),

        // MARK: - Ambiguous / Edge Cases

        ClassificationTestCase(
            id: "edge-001",
            text: """
            Pick up dry cleaning
            """,
            expectedType: .todo,
            category: .ambiguous,
            difficulty: .medium,
            notes: "Could be todo or reminder"
        ),

        ClassificationTestCase(
            id: "edge-002",
            text: """
            Coffee meeting notes
            Discussed new project timeline
            Next steps: draft proposal
            """,
            expectedType: .meeting,
            category: .edgeCase,
            difficulty: .medium,
            notes: "Informal meeting note"
        ),

        ClassificationTestCase(
            id: "edge-003",
            text: """
            Ideas from brainstorming session:
            1. Mobile app redesign
            2. API improvements
            3. Better analytics
            """,
            expectedType: .idea,
            category: .edgeCase,
            difficulty: .medium,
            notes: "List of ideas vs meeting notes"
        ),

        ClassificationTestCase(
            id: "edge-004",
            text: """
            Random thoughts on the project
            """,
            expectedType: .general,
            category: .ambiguous,
            difficulty: .hard,
            notes: "Too vague to classify"
        ),

        // MARK: - General Notes

        ClassificationTestCase(
            id: "general-001",
            text: """
            Just some notes from reading today
            Interesting perspective on productivity
            """,
            expectedType: .general,
            category: .obvious,
            difficulty: .easy,
            notes: "Clearly general"
        ),
    ]

    // MARK: - Test Suite Helpers

    /// Get tests filtered by category
    static func tests(for category: ClassificationTestCase.TestCategory) -> [ClassificationTestCase] {
        allTests.filter { $0.category == category }
    }

    /// Get tests filtered by difficulty
    static func tests(for difficulty: ClassificationTestCase.Difficulty) -> [ClassificationTestCase] {
        allTests.filter { $0.difficulty == difficulty }
    }

    /// Get tests filtered by expected type
    static func tests(for type: NoteType) -> [ClassificationTestCase] {
        allTests.filter { $0.expectedType == type }
    }
}
