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

@MainActor
@Observable
final class CameraViewModel {
    private(set) var isAuthorized = false
    private(set) var capturedImage: UIImage?
    private(set) var error: CameraError?
    private(set) var isProcessing = false

    private let ocrService = OCRService()
    private let imageProcessor = ImageProcessor()
    private let textClassifier = TextClassifier()
    private let spellCorrector = SpellCorrector()
    private let settings = SettingsManager.shared

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

        do {
            // Step 1: Just correct orientation - OCRService handles full preprocessing
            let correctedImage = imageProcessor.correctOrientation(image: image)

            // Step 2: Perform OCR with detailed word-level confidence
            // OCRService internally applies full preprocessing pipeline
            let ocrResult = try await ocrService.recognizeTextWithConfidence(from: correctedImage)

            print("🔍 Raw OCR result: \(ocrResult.fullText)")
            print("🔍 Average confidence: \(Int(ocrResult.averageConfidence * 100))%")

            // Step 3: Classify note type (before spell correction to catch trigger)
            let noteType = textClassifier.classifyNote(content: ocrResult.fullText)
            print("📋 Classified as: \(noteType.displayName)")

            // Step 4: Apply on-device spell correction
            let correctedText: String
            if noteType == .email {
                // Use email-specific correction for email notes
                let correction = spellCorrector.correctEmailContent(ocrResult.fullText)
                correctedText = correction.correctedText
                if correction.hasCorrections {
                    print("📝 Applied \(correction.correctionCount) spell corrections (email mode):")
                    for c in correction.corrections {
                        print("   '\(c.original)' → '\(c.corrected)'")
                    }
                } else {
                    print("📝 No spell corrections needed")
                }
            } else {
                // Use general spell correction
                let correction = spellCorrector.correctSpelling(ocrResult.fullText)
                correctedText = correction.correctedText
                if correction.hasCorrections {
                    print("📝 Applied \(correction.correctionCount) spell corrections:")
                    for c in correction.corrections {
                        print("   '\(c.original)' → '\(c.corrected)'")
                    }
                } else {
                    print("📝 No spell corrections needed")
                }
            }

            // Step 5: Apply LLM enhancement if enabled
            var finalText = correctedText
            print("🔧 LLM Check - autoEnhanceOCR: \(settings.autoEnhanceOCR), hasAPIKey: \(settings.hasAPIKey)")
            if settings.autoEnhanceOCR && settings.hasAPIKey {
                print("🤖 Auto-enhance enabled, calling LLM for \(noteType.rawValue) note...")
                do {
                    let result = try await LLMService.shared.enhanceOCRText(correctedText, noteType: noteType.rawValue)
                    finalText = result.enhancedText
                    print("✨ LLM enhanced text: \(result.enhancedText)")
                } catch {
                    print("⚠️ LLM enhancement failed, using spell-corrected text: \(error.localizedDescription)")
                }
            }

            print("✏️ Final text: \(finalText)")

            // Step 6: Save to Core Data with OCR result
            await saveNote(
                text: finalText,
                noteType: noteType,
                ocrResult: ocrResult,
                originalImage: image,
                thumbnail: imageProcessor.generateThumbnail(from: image)
            )

            isProcessing = false
        } catch OCRService.OCRError.noTextDetected {
            isProcessing = false
            error = .ocrFailed("No text detected in image. Try capturing again with better lighting.")
        } catch OCRService.OCRError.lowConfidence {
            isProcessing = false
            error = .ocrFailed("Text quality is too low. Try capturing with better lighting or focus.")
        } catch let caughtError {
            isProcessing = false
            self.error = .ocrFailed(caughtError.localizedDescription)
        }
    }

    private func saveNote(
        text: String,
        noteType: NoteType,
        ocrResult: OCRResult,
        originalImage: UIImage,
        thumbnail: UIImage?
    ) async {
        let context = CoreDataStack.shared.newBackgroundContext()

        // Encode OCR result on main actor before entering background context
        let ocrResultData = try? JSONEncoder().encode(ocrResult)
        let imageData = originalImage.jpegData(compressionQuality: 0.8)
        let thumbnailData = thumbnail?.jpegData(compressionQuality: 0.6)
        let avgConfidence = ocrResult.averageConfidence
        let lowConfidenceCount = ocrResult.lowConfidenceWords.count

        await context.perform {
            // Create note
            let note = Note.create(
                in: context,
                content: text,
                noteType: noteType.rawValue,
                originalImage: imageData
            )

            note.ocrConfidence = avgConfidence
            note.ocrResultData = ocrResultData

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

            case .email, .general:
                break // No special parsing needed
            }

            do {
                try CoreDataStack.shared.save(context: context)
                print("✅ Note saved - Type: \(noteType.displayName), Confidence: \(Int(avgConfidence * 100))%, Low-confidence words: \(lowConfidenceCount)")

                // Post notification for UI refresh
                NotificationCenter.default.post(
                    name: AppConstants.Notifications.noteCreated,
                    object: nil
                )
            } catch {
                Task { @MainActor in
                    self.error = .saveFailed
                }
                print("❌ Failed to save note: \(error)")
            }
        }
    }
}
