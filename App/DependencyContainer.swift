//
//  DependencyContainer.swift
//  QuillStack
//
//  Architecture refactoring: centralized dependency management.
//  Provides protocol-based service access for testability.
//

import Foundation

/// Centralized container for managing service dependencies.
/// Use `DependencyContainer.shared` for production, or create custom instances for testing.
///
/// Example usage in production:
/// ```swift
/// let ocr = await DependencyContainer.shared.ocrService
/// ```
///
/// Example usage in tests:
/// ```swift
/// let container = DependencyContainer(
///     ocrService: MockOCRService(),
///     textClassifier: MockTextClassifier()
/// )
/// ```
@MainActor
final class DependencyContainer: Sendable {

    // MARK: - Shared Instance

    /// Shared container instance with production services.
    /// Access from MainActor context or use `await`.
    static let shared = DependencyContainer()

    // MARK: - Services

    /// OCR service for text recognition from images
    let ocrService: OCRServiceProtocol

    /// Text classifier for note type detection
    let textClassifier: TextClassifierProtocol

    /// LLM service for AI-powered text enhancement
    let llmService: LLMServiceProtocol

    /// Calendar service for EventKit calendar integration
    let calendarService: CalendarServiceProtocol

    /// Reminders service for EventKit reminders integration
    let remindersService: RemindersServiceProtocol

    /// Integration registry for managing integration providers
    let integrationRegistry: IntegrationRegistry

    /// Action trigger parser for extracting inline action triggers
    let actionTriggerParser: ActionTriggerParserProtocol

    // MARK: - Initialization

    /// Initialize with default production services.
    init() {
        self.ocrService = OCRService.shared
        self.textClassifier = TextClassifier()
        self.llmService = LLMService.shared
        self.calendarService = CalendarService.shared
        self.remindersService = RemindersService.shared
        self.integrationRegistry = IntegrationRegistry.shared
        self.actionTriggerParser = ActionTriggerParser()
    }

    /// Initialize with custom services (for testing).
    /// - Parameters:
    ///   - ocrService: Custom OCR service implementation
    ///   - textClassifier: Custom text classifier implementation
    ///   - llmService: Custom LLM service implementation
    ///   - calendarService: Custom calendar service implementation
    ///   - remindersService: Custom reminders service implementation
    ///   - integrationRegistry: Custom integration registry
    ///   - actionTriggerParser: Custom action trigger parser implementation
    init(
        ocrService: OCRServiceProtocol? = nil,
        textClassifier: TextClassifierProtocol? = nil,
        llmService: LLMServiceProtocol? = nil,
        calendarService: CalendarServiceProtocol? = nil,
        remindersService: RemindersServiceProtocol? = nil,
        integrationRegistry: IntegrationRegistry? = nil,
        actionTriggerParser: ActionTriggerParserProtocol? = nil
    ) {
        self.ocrService = ocrService ?? OCRService.shared
        self.textClassifier = textClassifier ?? TextClassifier()
        self.llmService = llmService ?? LLMService.shared
        self.calendarService = calendarService ?? CalendarService.shared
        self.remindersService = remindersService ?? RemindersService.shared
        self.integrationRegistry = integrationRegistry ?? IntegrationRegistry.shared
        self.actionTriggerParser = actionTriggerParser ?? ActionTriggerParser()
    }
}

// MARK: - Convenience Accessors

extension DependencyContainer {
    /// Creates a CameraViewModel with this container's services.
    func makeCameraViewModel() -> CameraViewModel {
        CameraViewModel(ocrService: ocrService, textClassifier: textClassifier)
    }
}
