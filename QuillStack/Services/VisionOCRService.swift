import Foundation
import Vision
import UIKit
import FoundationModels
import os

/// On-device OCR service using Apple's Vision framework and FoundationModels for structured extraction.
/// Replaces cloud-based OCR with local text recognition and AI-powered data extraction.
actor VisionOCRService {
    static let shared = VisionOCRService()

    private let logger = Logger(subsystem: "com.quillstack", category: "VisionOCR")

    /// Combined result of OCR text recognition and optional structured data extraction.
    struct OCRResult: Sendable {
        let text: String
        let contact: ContactExtraction?
        let event: EventExtraction?
        let receipt: ReceiptExtraction?
    }

    // MARK: - Public API

    /// Performs on-device OCR and optional structured extraction based on selected tags.
    /// - Parameters:
    ///   - imageData: Raw image data to process
    ///   - tagNames: Set of tag names that trigger structured extraction (Contact, Event, Receipt)
    /// - Returns: OCRResult containing recognized text and any extracted structured data
    /// - Throws: VisionOCRError if image processing or text recognition fails
    func recognizeText(from imageData: Data, tagNames: Set<String> = []) async throws -> OCRResult {
        guard let image = UIImage(data: imageData) else {
            throw VisionOCRError.imageEncodingFailed
        }

        guard let cgImage = image.cgImage else {
            throw VisionOCRError.imageEncodingFailed
        }

        let rawText = try await performOCR(on: cgImage)

        guard !rawText.isEmpty else {
            throw VisionOCRError.emptyResponse
        }

        // Refine OCR text using on-device LLM to fix common OCR issues
        let refinedText = await refineOCRText(rawText)
        let text = refinedText ?? rawText // Fall back to raw text if refinement fails

        // Check if any tags need structured extraction
        let extractionTags = tagNames.intersection(["Contact", "Event", "Receipt"])

        var contact: ContactExtraction?
        var event: EventExtraction?
        var receipt: ReceiptExtraction?

        if !extractionTags.isEmpty {
            // Perform on-device structured extraction using refined text
            if extractionTags.contains("Contact") {
                contact = await extractContact(from: text)
            }
            if extractionTags.contains("Event") {
                event = await extractEvent(from: text)
            }
            if extractionTags.contains("Receipt") {
                receipt = await extractReceipt(from: text)
            }
        }

        logger.info("OCR complete: \(text.count) chars, refined=\(refinedText != nil), contact=\(contact != nil), event=\(event != nil), receipt=\(receipt != nil)")
        return OCRResult(text: text, contact: contact, event: event, receipt: receipt)
    }

    // MARK: - Vision OCR

    /// Performs text recognition on an image using Apple's Vision framework.
    /// - Parameter cgImage: Core Graphics image to analyze
    /// - Returns: Recognized text as a single string with newline separators
    /// - Throws: Error if Vision request fails
    private func performOCR(on cgImage: CGImage) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }

                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                continuation.resume(returning: recognizedText)
            }

            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Refines raw OCR text using on-device LLM to correct common OCR errors.
    /// - Parameter rawText: Text directly from Vision OCR
    /// - Returns: Cleaned and corrected text, or nil if refinement fails
    private func refineOCRText(_ rawText: String) async -> String? {
        let prompt = """
        Correct the following OCR text by fixing spacing issues, character recognition errors (O/0, I/l/1, S/5), and adding missing punctuation. Preserve the original structure and line breaks. Do not add content that wasn't in the original.

        ---
        \(String(rawText.prefix(2000)))
        ---
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt, generating: RefinedText.self)
            let refined = response.content.text.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !refined.isEmpty else {
                logger.warning("OCR refinement returned empty text")
                return nil
            }

            logger.info("OCR refinement: \(rawText.count) chars → \(refined.count) chars")
            return refined
        } catch {
            logger.warning("OCR refinement failed: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Structured Extraction

    /// Extracts contact information from OCR text using on-device AI.
    /// - Parameter text: OCR text to analyze
    /// - Returns: ContactExtraction if successful, nil if extraction fails
    private func extractContact(from text: String) async -> ContactExtraction? {
        let prompt = """
        Extract contact information from the following text. Only include fields that are clearly visible.

        ---
        \(String(text.prefix(2000)))
        ---
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: prompt,
                generating: ExtractedContact.self
            )
            let c = response.content
            logger.info("Contact extraction: name=\(c.name ?? "none")")
            return ContactExtraction(
                name: c.name,
                phone: c.phone,
                email: c.email,
                company: c.company,
                address: c.address,
                jobTitle: c.jobTitle,
                url: c.url
            )
        } catch {
            logger.warning("Contact extraction failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Extracts event information from OCR text using on-device AI.
    /// - Parameter text: OCR text to analyze
    /// - Returns: EventExtraction if successful, nil if extraction fails
    private func extractEvent(from text: String) async -> EventExtraction? {
        let currentYear = Calendar.current.component(.year, from: Date())
        let prompt = """
        Extract event information from the following text. Only include fields that are clearly visible.

        IMPORTANT: When parsing dates, if no year is specified, use \(currentYear) as the year. Be precise with day and month values.

        ---
        \(String(text.prefix(2000)))
        ---
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: prompt,
                generating: ExtractedEvent.self
            )
            let e = response.content
            logger.info("Event extraction: title=\(e.title ?? "none")")
            return EventExtraction(
                title: e.title,
                date: e.date,
                time: e.time,
                endTime: e.endTime,
                location: e.location,
                description: e.description
            )
        } catch {
            logger.warning("Event extraction failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Extracts receipt information from OCR text using on-device AI.
    /// - Parameter text: OCR text to analyze
    /// - Returns: ReceiptExtraction if successful, nil if extraction fails
    private func extractReceipt(from text: String) async -> ReceiptExtraction? {
        let prompt = """
        Extract receipt information from the following text. Only include fields that are clearly visible.

        ---
        \(String(text.prefix(2000)))
        ---
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: prompt,
                generating: ExtractedReceipt.self
            )
            let r = response.content
            logger.info("Receipt extraction: vendor=\(r.vendor ?? "none"), total=\(r.total ?? "none")")
            return ReceiptExtraction(
                vendor: r.vendor,
                total: r.total,
                date: r.date,
                currency: r.currency
            )
        } catch {
            logger.warning("Receipt extraction failed: \(error.localizedDescription)")
            return nil
        }
    }

}

// MARK: - Errors

enum VisionOCRError: Error, LocalizedError {
    case imageEncodingFailed
    case emptyResponse
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .imageEncodingFailed:
            "Failed to process image"
        case .emptyResponse:
            "No text found in image"
        case .extractionFailed(let message):
            "Extraction failed: \(message)"
        }
    }
}

// MARK: - Extraction Models

@Generable(description: "Refined OCR text with corrections")
private struct RefinedText {
    @Guide(description: "The corrected text with spacing, character, and punctuation fixes applied")
    var text: String
}

@Generable(description: "Contact information extracted from text")
private struct ExtractedContact {
    @Guide(description: "Full name")
    var name: String?

    @Guide(description: "Phone number")
    var phone: String?

    @Guide(description: "Email address")
    var email: String?

    @Guide(description: "Company or organization")
    var company: String?

    @Guide(description: "Physical address")
    var address: String?

    @Guide(description: "Job title or role")
    var jobTitle: String?

    @Guide(description: "Website URL")
    var url: String?
}

@Generable(description: "Event information extracted from text")
private struct ExtractedEvent {
    @Guide(description: "Event title")
    var title: String?

    @Guide(description: "Date in ISO 8601 format (YYYY-MM-DD). If year is missing from source text, use current year.")
    var date: String?

    @Guide(description: "Start time")
    var time: String?

    @Guide(description: "End time")
    var endTime: String?

    @Guide(description: "Venue or address")
    var location: String?

    @Guide(description: "Event description")
    var description: String?
}

@Generable(description: "Receipt information extracted from text")
private struct ExtractedReceipt {
    @Guide(description: "Store or business name")
    var vendor: String?

    @Guide(description: "Total amount")
    var total: String?

    @Guide(description: "Transaction date in ISO 8601")
    var date: String?

    @Guide(description: "Currency code (USD, EUR, etc.)")
    var currency: String?
}

