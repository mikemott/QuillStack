//
//  CameraViewModel.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import SwiftUI
import AVFoundation
import Combine
import CoreData
import Sentry
import OSLog

@MainActor
@Observable
final class CameraViewModel {
    private(set) var isAuthorized = false
    private(set) var capturedImage: UIImage?
    private(set) var error: CameraError?
    private(set) var isProcessing = false

    // Section detection (QUI-159)
    var showSectionPreview = false
    private(set) var detectedSections: [DetectedSection] = []
    private(set) var sectionDetectionMethod: SectionDetectionResult.DetectionMethod = .none
    private var pendingProcessData: (ocrResult: OCRResult, image: UIImage)?

    // Dependencies (protocol-based for testability)
    private let ocrService: OCRServiceProtocol
    private let textClassifier: TextClassifierProtocol
    private let sectionDetector = SectionDetector.shared
    private let imageProcessor = ImageProcessor()
    private let spellCorrector = SpellCorrector()
    private let settings = SettingsManager.shared
    private let networkMonitor = NetworkMonitor.shared
    private let processingQueue = ProcessingQueue.shared

    // Cache existing tags for vocabulary consistency
    private var existingTags: [String] = []

    /// Initialize with default shared services
    init() {
        self.ocrService = OCRService.shared
        self.textClassifier = TextClassifier()
    }

    /// Initialize with custom services (for testing)
    init(ocrService: OCRServiceProtocol, textClassifier: TextClassifierProtocol) {
        self.ocrService = ocrService
        self.textClassifier = textClassifier
    }

    /// Initialize with custom OCR service only (for testing)
    init(ocrService: OCRServiceProtocol) {
        self.ocrService = ocrService
        self.textClassifier = TextClassifier()
    }

    /// Initialize with custom text classifier only (for testing)
    init(textClassifier: TextClassifierProtocol) {
        self.ocrService = OCRService.shared
        self.textClassifier = textClassifier
    }

    enum CameraError: LocalizedError {
        case unauthorized
        case captureFailed
        case ocrFailed(String)
        case saveFailed

        var errorDescription: String? {
            switch self {
            case .unauthorized:
                return "Camera access is required to capture notes"
            case .captureFailed:
                return "Failed to capture image"
            case .ocrFailed(let reason):
                return "Could not recognize text: \(reason)"
            case .saveFailed:
                return "Failed to save note"
            }
        }
    }

    func processImage(_ image: UIImage) async {
        isProcessing = true
        error = nil

        // Load existing tags for vocabulary consistency (if not already loaded)
        if existingTags.isEmpty {
            existingTags = await fetchExistingTags()
            // Track tag vocabulary loading for debugging (no sensitive data)
            let breadcrumb = Breadcrumb(level: .debug, category: "tag_suggestion")
            breadcrumb.message = "Loaded existing tags for vocabulary consistency"
            breadcrumb.data = ["tag_count": existingTags.count]
            SentrySDK.addBreadcrumb(breadcrumb)
        }

        // Sentry: Track capture start
        let breadcrumb = Breadcrumb(level: .info, category: "capture")
        breadcrumb.message = "Started processing captured image"
        breadcrumb.data = [
            "image_size": "\(Int(image.size.width))x\(Int(image.size.height))"
        ]
        SentrySDK.addBreadcrumb(breadcrumb)

        do {
            // Step 1: Just correct orientation - OCRService handles full preprocessing
            let correctedImage = imageProcessor.correctOrientation(image: image)

            // Step 2: Perform OCR with detailed word-level confidence
            // OCRService internally applies full preprocessing pipeline
            let ocrResult = try await ocrService.recognizeTextWithConfidence(from: correctedImage)

            print("🔍 Raw OCR result: \(ocrResult.fullText)")
            print("🔍 Average confidence: \(Int(ocrResult.averageConfidence * 100))%")

            // Sentry: Track OCR completion
            let ocrBreadcrumb = Breadcrumb(level: .info, category: "ocr")
            ocrBreadcrumb.message = "OCR completed"
            ocrBreadcrumb.data = [
                "text_length": ocrResult.fullText.count,
                "confidence": Int(ocrResult.averageConfidence * 100),
                "low_confidence_words": ocrResult.lowConfidenceWords.count
            ]
            SentrySDK.addBreadcrumb(ocrBreadcrumb)

            // Step 3: Check for multi-section detection (QUI-159)
            let sectionResult = await sectionDetector.detectSections(in: ocrResult.fullText, settings: settings)

            if sectionResult.shouldAutoSplit && sectionResult.sections.count >= 2 {
                // Multiple sections detected - show preview for user decision
                pendingProcessData = (ocrResult, correctedImage)
                detectedSections = sectionResult.sections
                sectionDetectionMethod = sectionResult.detectionMethod
                showSectionPreview = true
                isProcessing = false

                print("📋 Detected \(sectionResult.sections.count) sections - showing preview")
                return
            }

            // Step 4: Split into sections based on detected tags (existing logic)
            let sections = textClassifier.splitIntoSections(content: ocrResult.fullText)
            print("📋 Detected \(sections.count) section(s)")

            // Sentry: Track section splitting
            let sectionBreadcrumb = Breadcrumb(level: .info, category: "classification")
            sectionBreadcrumb.message = "Split into \(sections.count) section(s)"
            sectionBreadcrumb.data = [
                "section_count": sections.count,
                "types": sections.map { $0.noteType.rawValue }.joined(separator: ", ")
            ]
            SentrySDK.addBreadcrumb(sectionBreadcrumb)

            // Step 4: Process each section separately
            let learnedCorrections = HandwritingLearningService.shared.getLearnedCorrections()
            let learnedCount = learnedCorrections.count
            if learnedCount > 0 {
                print("📚 Using \(learnedCount) learned corrections")
            }

            let offlineQueue = OfflineQueueService.shared
            let thumbnail = imageProcessor.generateThumbnail(from: image)

            for (index, section) in sections.enumerated() {
                print("\n--- Section \(index + 1)/\(sections.count): \(section.noteType.displayName) ---")

                // Apply spell correction for this section
                let correctedText: String
                if section.noteType == .email {
                    let correction = spellCorrector.correctEmailContent(section.content, learnedCorrections: learnedCorrections)
                    correctedText = correction.correctedText
                    if correction.hasCorrections {
                        print("📝 Applied \(correction.correctionCount) spell corrections (email mode)")
                    }
                } else {
                    let correction = spellCorrector.correctSpelling(section.content, learnedCorrections: learnedCorrections)
                    correctedText = correction.correctedText
                    if correction.hasCorrections {
                        print("📝 Applied \(correction.correctionCount) spell corrections")
                    }
                }

                // Apply LLM enhancement if enabled
                var finalText = correctedText
                var processingState: NoteProcessingState = .enhanced

                if settings.autoEnhanceOCR && settings.claudeAPIKey != nil {
                    // Check both online status AND rate limits
                    if networkMonitor.isConnected && LLMRateLimiter.shared.canMakeCall() {
                        print("🤖 Auto-enhance enabled, calling LLM for \(section.noteType.rawValue) note...")

                        // Sentry: Track LLM call
                        let llmBreadcrumb = Breadcrumb(level: .info, category: "llm")
                        llmBreadcrumb.message = "Starting LLM enhancement"
                        llmBreadcrumb.data = ["note_type": section.noteType.rawValue]
                        SentrySDK.addBreadcrumb(llmBreadcrumb)

                        do {
                            let result = try await LLMService.shared.enhanceOCRText(correctedText, noteType: section.noteType.rawValue)
                            finalText = result.enhancedText
                            processingState = .enhanced
                            print("✨ LLM enhanced text")

                            // Record call for rate limiting
                            LLMRateLimiter.shared.recordCall()

                            // Sentry: Track LLM success
                            let successBreadcrumb = Breadcrumb(level: .info, category: "llm")
                            successBreadcrumb.message = "LLM enhancement completed"
                            SentrySDK.addBreadcrumb(successBreadcrumb)
                        } catch {
                            print("⚠️ LLM enhancement failed: \(error.localizedDescription)")

                            // Sentry: Track LLM failure (not as error, just breadcrumb)
                            let failBreadcrumb = Breadcrumb(level: .warning, category: "llm")
                            failBreadcrumb.message = "LLM enhancement failed, queuing for later"
                            failBreadcrumb.data = ["error": error.localizedDescription]
                            SentrySDK.addBreadcrumb(failBreadcrumb)

                            processingState = .pendingEnhancement
                        }
                    } else {
                        if !networkMonitor.isConnected {
                            print("📴 Offline - note will be enhanced when online")
                            processingState = .ocrOnly
                        } else {
                            print("🚫 Rate limited - queueing enhancement for later")
                            processingState = .pendingEnhancement
                        }
                    }
                } else {
                    // No auto-enhancement enabled, OCR only
                    processingState = .enhanced
                }

                // Track OCR completion (metadata only, no content)
                let ocrBreadcrumb = Breadcrumb(level: .debug, category: "ocr")
                ocrBreadcrumb.message = "OCR text extraction completed"
                ocrBreadcrumb.data = ["text_length": finalText.count]
                SentrySDK.addBreadcrumb(ocrBreadcrumb)

                // Suggest tags if auto-enhancement is enabled and we have an API key
                var suggestedTags: [String]? = nil
                if settings.autoEnhanceOCR && settings.claudeAPIKey != nil {
                    if offlineQueue.isOnline && LLMRateLimiter.shared.canMakeCall() {
                        do {
                            let suggestion = try await LLMService.shared.suggestTags(
                                for: finalText,
                                existingTags: existingTags
                            )
                            suggestedTags = suggestion.allTags

                            // Track success (metadata only, no tag content)
                            let tagBreadcrumb = Breadcrumb(level: .debug, category: "tag_suggestion")
                            tagBreadcrumb.message = "Tags suggested successfully"
                            tagBreadcrumb.data = [
                                "tag_count": suggestedTags!.count,
                                "confidence": suggestion.confidence
                            ]
                            SentrySDK.addBreadcrumb(tagBreadcrumb)

                            // Record call for rate limiting
                            LLMRateLimiter.shared.recordCall()
                        } catch {
                            // Log error with context for debugging (no sensitive data)
                            SentrySDK.capture(error: error) { scope in
                                scope.setLevel(.warning)
                                scope.setContext(value: [
                                    "operation": "tag_suggestion",
                                    "error_type": String(describing: type(of: error))
                                ], key: "tag_suggestion_error")
                            }
                            // Don't block note creation if tag suggestion fails
                        }
                    }
                }

                // Save this section as a separate note
                // Only attach image to first section to avoid duplication
                let noteId = await saveNote(
                    text: finalText,
                    noteType: section.noteType,
                    ocrResult: ocrResult,
                    originalImage: index == 0 ? image : nil,
                    thumbnail: index == 0 ? thumbnail : nil,
                    suggestedTags: suggestedTags,
                    processingState: processingState
                )

                // Apply image retention policy
                if let noteId = noteId {
                    await applyImageRetentionPolicy(noteId: noteId)
                }
            }

            // Sentry: Track successful completion
            let completeBreadcrumb = Breadcrumb(level: .info, category: "capture")
            completeBreadcrumb.message = "Image processing completed successfully"
            completeBreadcrumb.data = ["sections_saved": sections.count]
            SentrySDK.addBreadcrumb(completeBreadcrumb)

            isProcessing = false
        } catch OCRService.OCRError.noTextDetected {
            isProcessing = false
            error = .ocrFailed("No text detected in image. Try capturing again with better lighting.")

            // Sentry: Track OCR error
            SentrySDK.capture(error: OCRService.OCRError.noTextDetected) { scope in
                scope.setLevel(.warning)
                scope.setContext(value: ["error_type": "no_text_detected"], key: "ocr_error")
            }
        } catch OCRService.OCRError.lowConfidence {
            isProcessing = false
            error = .ocrFailed("Text quality is too low. Try capturing with better lighting or focus.")

            // Sentry: Track low confidence error
            SentrySDK.capture(error: OCRService.OCRError.lowConfidence) { scope in
                scope.setLevel(.warning)
                scope.setContext(value: ["error_type": "low_confidence"], key: "ocr_error")
            }
        } catch let caughtError {
            isProcessing = false
            self.error = .ocrFailed(caughtError.localizedDescription)

            // Sentry: Capture unexpected error
            SentrySDK.capture(error: caughtError) { scope in
                scope.setLevel(.error)
                scope.setContext(value: [
                    "error_description": caughtError.localizedDescription,
                    "flow": "image_processing"
                ], key: "capture_error")
            }
        }
    }

    private func saveNote(
        text: String,
        noteType: NoteType,
        ocrResult: OCRResult,
        originalImage: UIImage?,
        thumbnail: UIImage?,
        suggestedTags: [String]? = nil,
        sourceNoteID: UUID? = nil,
        processingState: NoteProcessingState = .enhanced
    ) async -> UUID? {
        let context = CoreDataStack.shared.newBackgroundContext()

        // Encode OCR result on main actor before entering background context
        let ocrResultData = try? JSONEncoder().encode(ocrResult)
        let imageData = originalImage?.jpegData(compressionQuality: 0.8)
        let thumbnailData = thumbnail?.jpegData(compressionQuality: 0.6)
        let avgConfidence = ocrResult.averageConfidence
        let lowConfidenceCount = ocrResult.lowConfidenceWords.count

        return await context.perform {
            // Create note
            let note = Note.create(
                in: context,
                content: text,
                noteType: noteType.rawValue,
                originalImage: imageData
            )

            let noteId = note.id

            note.ocrConfidence = avgConfidence
            note.ocrResultData = ocrResultData
            note.sourceNoteID = sourceNoteID // Link to source note if this is a split section
            note.processingState = processingState
            // note.captureSource = "camera" // TODO: Add this field to Note model

            if let thumbnailData = thumbnailData {
                note.thumbnail = thumbnailData
            }

            // Apply suggested tags if available (with validation)
            if let tags = suggestedTags {
                let validatedTags = self.validateTags(tags)
                for tagName in validatedTags {
                    note.addTagEntity(named: tagName, in: context)
                }

                // Log if any tags were rejected
                if validatedTags.count < tags.count {
                    let rejectedCount = tags.count - validatedTags.count
                    let breadcrumb = Breadcrumb(level: .warning, category: "tag_suggestion")
                    breadcrumb.message = "Some LLM-suggested tags were rejected"
                    breadcrumb.data = ["rejected_count": rejectedCount]
                    SentrySDK.addBreadcrumb(breadcrumb)
                }
            }

            // Parse based on note type
            switch noteType {
            case .todo:
                let parser = TodoParser(context: context)
                let todos = parser.parseTodos(from: text, note: note)
                print("📝 Parsed \(todos.count) todo items from note")

            case .meeting:
                let parser = MeetingParser(context: context)
                if let meeting = parser.parseMeeting(from: text, note: note) {
                    print("📅 Parsed meeting: \(meeting.title)")
                }

            case .contact:
                // Contact parsing happens in ContactDetailView (on-the-fly)
                let parsed = ContactParser.parse(text)
                print("👤 Detected contact: \(parsed.displayName)")

            case .email, .general, .claudePrompt, .reminder, .expense, .shopping, .recipe, .event, .journal, .idea:
                break // No special parsing needed - handled in detail views
            }

            do {
                try CoreDataStack.shared.save(context: context)

                // Post notification for UI refresh
                NotificationCenter.default.post(
                    name: AppConstants.Notifications.noteCreated,
                    object: nil
                )

                // Extract structured data asynchronously (non-blocking)
                Task { @MainActor in
                    // Fetch the note in the view context for extraction
                    let viewContext = CoreDataStack.shared.persistentContainer.viewContext
                    let request = NSFetchRequest<Note>(entityName: "Note")
                    request.predicate = NSPredicate(format: "id == %@", noteId as CVarArg)
                    request.fetchLimit = 1

                    do {
                        if let savedNote = try viewContext.fetch(request).first {
                            let extractionService = DataExtractionService()
                            await extractionService.extractData(from: savedNote)

                            // Save the extracted data
                            do {
                                try viewContext.save()
                            } catch {
                                Logger(subsystem: "com.quillstack", category: "DataExtraction")
                                    .error("Failed to save extracted data: \(error.localizedDescription, privacy: .public)")
                            }
                        }
                    } catch {
                        Logger(subsystem: "com.quillstack", category: "DataExtraction")
                            .error("Failed to fetch note for extraction: \(error.localizedDescription, privacy: .public)")
                    }
                }

                return noteId
            } catch {
                Task { @MainActor in
                    self.error = .saveFailed
                }
                return nil
            }
        }
    }

    /// Applies the image retention policy after OCR processing
    private func applyImageRetentionPolicy(noteId: UUID) async {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        let request = NSFetchRequest<Note>(entityName: "Note")
        request.predicate = NSPredicate(format: "id == %@", noteId as CVarArg)
        request.fetchLimit = 1

        do {
            if let note = try context.fetch(request).first {
                await ImageRetentionService.shared.processAfterOCR(note: note)
            }
        } catch {
            // Non-critical error - log for debugging but don't fail the capture
            SentrySDK.capture(error: error) { scope in
                scope.setLevel(.warning)
                scope.setContext(value: [
                    "operation": "image_retention_policy",
                    "note_id": noteId.uuidString
                ], key: "retention_error")
            }
        }
    }

    /// Fetch existing tags for vocabulary consistency
    private func fetchExistingTags() async -> [String] {
        let context = CoreDataStack.shared.persistentContainer.viewContext
        return await context.perform {
            let request = Tag.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Tag.createdAt, ascending: false)]

            do {
                let tags = try context.fetch(request)
                // Sort by usage count and return top 50 tag names
                return tags
                    .sorted { $0.noteCount > $1.noteCount }
                    .prefix(50)
                    .map { $0.name }
            } catch {
                // Log fetch failure but return empty array (non-blocking)
                SentrySDK.capture(error: error) { scope in
                    scope.setLevel(.warning)
                    scope.setContext(value: [
                        "operation": "fetch_existing_tags"
                    ], key: "tag_fetch_error")
                }
                return []
            }
        }
    }

    /// Validate LLM-generated tags before applying to notes
    /// - Parameter tags: Array of tag names from LLM
    /// - Returns: Filtered array of valid tag names
    private func validateTags(_ tags: [String]) -> [String] {
        let maxTags = 10
        let maxTagLength = 50
        let validCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))

        return tags.prefix(maxTags).compactMap { tagName in
            let trimmed = tagName.trimmingCharacters(in: .whitespaces)

            // Validate: non-empty, length limit, valid characters only
            guard !trimmed.isEmpty,
                  trimmed.count <= maxTagLength,
                  trimmed.rangeOfCharacter(from: validCharacterSet.inverted) == nil else {
                return nil
            }

            return trimmed
        }
    }

    // MARK: - Section Detection (QUI-159)

    /// User chose to split into multiple notes
    func handleSplitNotes() async {
        guard let (ocrResult, image) = pendingProcessData else { return }

        showSectionPreview = false
        isProcessing = true

        // Create source note ID for linking
        let sourceNoteID = UUID()

        print("📋 Splitting into \(detectedSections.count) notes with sourceNoteID: \(sourceNoteID)")

        // Process each detected section
        for (index, section) in detectedSections.enumerated() {
            await processSplitSection(
                section: section,
                index: index,
                sourceNoteID: sourceNoteID,
                ocrResult: ocrResult,
                image: image
            )
        }

        // Cleanup
        pendingProcessData = nil
        detectedSections = []
        isProcessing = false
    }

    /// User chose to keep as single note
    func handleKeepSingleNote() async {
        guard let (ocrResult, image) = pendingProcessData else { return }

        showSectionPreview = false
        pendingProcessData = nil
        detectedSections = []

        print("📋 User chose to keep as single note - processing normally")

        // Continue with existing processImage logic
        await continueProcessing(ocrResult: ocrResult, image: image)
    }

    /// Continue processing with existing logic (extracted from processImage)
    private func continueProcessing(ocrResult: OCRResult, image: UIImage) async {
        isProcessing = true

        // Step 3: Split into sections based on detected tags (existing logic)
        let sections = textClassifier.splitIntoSections(content: ocrResult.fullText)
        print("📋 Detected \(sections.count) section(s)")

        // Sentry: Track section splitting
        let sectionBreadcrumb = Breadcrumb(level: .info, category: "classification")
        sectionBreadcrumb.message = "Split into \(sections.count) section(s)"
        sectionBreadcrumb.data = [
            "section_count": sections.count,
            "types": sections.map { $0.noteType.rawValue }.joined(separator: ", ")
        ]
        SentrySDK.addBreadcrumb(sectionBreadcrumb)

        // Step 4: Process each section separately
        let learnedCorrections = HandwritingLearningService.shared.getLearnedCorrections()
        let learnedCount = learnedCorrections.count
        if learnedCount > 0 {
            print("📚 Using \(learnedCount) learned corrections")
        }

        let thumbnail = imageProcessor.generateThumbnail(from: image)

        for (index, section) in sections.enumerated() {
            await processSection(
                section: section,
                index: index,
                totalSections: sections.count,
                ocrResult: ocrResult,
                image: image,
                thumbnail: thumbnail,
                learnedCorrections: learnedCorrections
            )
        }

        // Sentry: Track successful completion
        let completeBreadcrumb = Breadcrumb(level: .info, category: "capture")
        completeBreadcrumb.message = "Image processing completed successfully"
        completeBreadcrumb.data = ["sections_saved": sections.count]
        SentrySDK.addBreadcrumb(completeBreadcrumb)

        isProcessing = false
    }

    /// Process a split section (from section detection)
    private func processSplitSection(
        section: DetectedSection,
        index: Int,
        sourceNoteID: UUID,
        ocrResult: OCRResult,
        image: UIImage
    ) async {
        print("\n--- Processing section \(index + 1): \(section.suggestedType.displayName) ---")

        // Apply spell correction
        let learnedCorrections = HandwritingLearningService.shared.getLearnedCorrections()
        let spellCorrector = SpellCorrector()

        let correctedText: String
        if section.suggestedType == .email {
            let correction = spellCorrector.correctEmailContent(section.content, learnedCorrections: learnedCorrections)
            correctedText = correction.correctedText
        } else {
            let correction = spellCorrector.correctSpelling(section.content, learnedCorrections: learnedCorrections)
            correctedText = correction.correctedText
        }

        // Apply LLM enhancement if enabled
        var finalText = correctedText
        var processingState: NoteProcessingState = .enhanced

        if settings.autoEnhanceOCR && settings.claudeAPIKey != nil {
            if networkMonitor.isConnected && LLMRateLimiter.shared.canMakeCall() {
                do {
                    let result = try await LLMService.shared.enhanceOCRText(correctedText, noteType: section.suggestedType.rawValue)
                    finalText = result.enhancedText
                    processingState = .enhanced
                    LLMRateLimiter.shared.recordCall()
                } catch {
                    processingState = .pendingEnhancement
                }
            } else {
                if !networkMonitor.isConnected {
                    processingState = .ocrOnly
                } else {
                    processingState = .pendingEnhancement
                }
            }
        } else {
            processingState = .enhanced
        }

        // Generate thumbnail only for first section
        let thumbnail = index == 0 ? imageProcessor.generateThumbnail(from: image) : nil

        // Use suggested tags from section detection
        let tags = section.suggestedTags.isEmpty ? nil : section.suggestedTags

        // Save note with sourceNoteID
        let noteId = await saveNote(
            text: finalText,
            noteType: section.suggestedType,
            ocrResult: ocrResult,
            originalImage: index == 0 ? image : nil,
            thumbnail: thumbnail,
            suggestedTags: tags,
            sourceNoteID: sourceNoteID, // All notes in the split group share the same sourceNoteID
            processingState: processingState
        )

        // Apply image retention policy
        if let noteId = noteId {
            await applyImageRetentionPolicy(noteId: noteId)
        }
    }

    /// Process a section from existing split logic (extracted for reuse)
    private func processSection(
        section: NoteSection,
        index: Int,
        totalSections: Int,
        ocrResult: OCRResult,
        image: UIImage,
        thumbnail: UIImage?,
        learnedCorrections: [String: String]
    ) async {
        print("\n--- Section \(index + 1)/\(totalSections): \(section.noteType.displayName) ---")

        // Apply spell correction for this section
        let correctedText: String
        if section.noteType == .email {
            let correction = spellCorrector.correctEmailContent(section.content, learnedCorrections: learnedCorrections)
            correctedText = correction.correctedText
            if correction.hasCorrections {
                print("📝 Applied \(correction.correctionCount) spell corrections (email mode)")
            }
        } else {
            let correction = spellCorrector.correctSpelling(section.content, learnedCorrections: learnedCorrections)
            correctedText = correction.correctedText
            if correction.hasCorrections {
                print("📝 Applied \(correction.correctionCount) spell corrections")
            }
        }

        // Apply LLM enhancement if enabled
        var finalText = correctedText
        var processingState: NoteProcessingState = .enhanced

        if settings.autoEnhanceOCR && settings.claudeAPIKey != nil {
            if networkMonitor.isConnected && LLMRateLimiter.shared.canMakeCall() {
                print("🤖 Auto-enhance enabled, calling LLM for \(section.noteType.rawValue) note...")

                do {
                    let result = try await LLMService.shared.enhanceOCRText(correctedText, noteType: section.noteType.rawValue)
                    finalText = result.enhancedText
                    processingState = .enhanced
                    print("✨ LLM enhanced text")
                    LLMRateLimiter.shared.recordCall()
                } catch {
                    print("⚠️ LLM enhancement failed: \(error.localizedDescription)")
                    processingState = .pendingEnhancement
                }
            } else {
                if !networkMonitor.isConnected {
                    print("📴 Offline - note will be enhanced when online")
                    processingState = .ocrOnly
                } else {
                    print("🚫 Rate limited - queueing enhancement for later")
                    processingState = .pendingEnhancement
                }
            }
        } else {
            processingState = .enhanced
        }

        // Suggest tags if auto-enhancement is enabled
        var suggestedTags: [String]? = nil
        if settings.autoEnhanceOCR && settings.claudeAPIKey != nil {
            if networkMonitor.isConnected && LLMRateLimiter.shared.canMakeCall() {
                do {
                    let suggestion = try await LLMService.shared.suggestTags(
                        for: finalText,
                        existingTags: existingTags
                    )
                    suggestedTags = suggestion.allTags
                    LLMRateLimiter.shared.recordCall()
                } catch {
                    // Don't block note creation if tag suggestion fails
                }
            }
        }

        // Save this section as a separate note
        let noteId = await saveNote(
            text: finalText,
            noteType: section.noteType,
            ocrResult: ocrResult,
            originalImage: index == 0 ? image : nil,
            thumbnail: index == 0 ? thumbnail : nil,
            suggestedTags: suggestedTags,
            processingState: processingState
        )

        // Apply image retention policy
        if let noteId = noteId {
            await applyImageRetentionPolicy(noteId: noteId)
        }
    }
}
