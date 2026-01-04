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

@MainActor
@Observable
final class CameraViewModel {
    private(set) var isAuthorized = false
    private(set) var capturedImage: UIImage?
    private(set) var error: CameraError?
    private(set) var isProcessing = false

    // Dependencies (protocol-based for testability)
    private let ocrService: OCRServiceProtocol
    private let textClassifier: TextClassifierProtocol
    private let imageProcessor = ImageProcessor()
    private let spellCorrector = SpellCorrector()
    private let settings = SettingsManager.shared

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

            // Step 3: Split into sections based on detected tags
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
                var shouldQueueEnhancement = false

                if settings.autoEnhanceOCR && settings.claudeAPIKey != nil {
                    // Check both online status AND rate limits
                    if offlineQueue.isOnline && LLMRateLimiter.shared.canMakeCall() {
                        print("🤖 Auto-enhance enabled, calling LLM for \(section.noteType.rawValue) note...")

                        // Sentry: Track LLM call
                        let llmBreadcrumb = Breadcrumb(level: .info, category: "llm")
                        llmBreadcrumb.message = "Starting LLM enhancement"
                        llmBreadcrumb.data = ["note_type": section.noteType.rawValue]
                        SentrySDK.addBreadcrumb(llmBreadcrumb)

                        do {
                            let result = try await LLMService.shared.enhanceOCRText(correctedText, noteType: section.noteType.rawValue)
                            finalText = result.enhancedText
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

                            shouldQueueEnhancement = true
                        }
                    } else {
                        if !offlineQueue.isOnline {
                            print("📴 Offline - queueing enhancement for later")
                        } else {
                            print("🚫 Rate limited - queueing enhancement for later")
                        }
                        shouldQueueEnhancement = true
                    }
                }

                print("✏️ Final text: \(finalText)")

                // Save this section as a separate note
                // Only attach image to first section to avoid duplication
                let noteId = await saveNote(
                    text: finalText,
                    noteType: section.noteType,
                    ocrResult: ocrResult,
                    originalImage: index == 0 ? image : nil,
                    thumbnail: index == 0 ? thumbnail : nil
                )

                // Queue enhancement if needed
                if shouldQueueEnhancement, let noteId = noteId {
                    await offlineQueue.enqueue(
                        noteId: noteId,
                        text: correctedText,
                        noteType: section.noteType.rawValue
                    )
                }

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
        thumbnail: UIImage?
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
            // note.captureSource = "camera" // TODO: Add this field to Note model

            if let thumbnailData = thumbnailData {
                note.thumbnail = thumbnailData
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

            case .email, .general, .claudePrompt, .reminder, .expense, .shopping, .recipe, .event, .idea:
                break // No special parsing needed - handled in detail views
            }

            do {
                try CoreDataStack.shared.save(context: context)

                // Post notification for UI refresh
                NotificationCenter.default.post(
                    name: AppConstants.Notifications.noteCreated,
                    object: nil
                )

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
            // Non-critical error - don't fail the capture
        }
    }
}
