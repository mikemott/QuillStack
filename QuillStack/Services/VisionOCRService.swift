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
        let todo: TodoExtraction?
    }

    // MARK: - Public API

    /// Performs on-device OCR and optional structured extraction based on selected tags.
    /// - Parameters:
    ///   - imageData: Raw image data to process
    ///   - tagNames: Set of tag names that trigger structured extraction (Contact, Event, Receipt, To-Do)
    /// - Returns: OCRResult containing recognized text and any extracted structured data
    /// - Throws: VisionOCRError if image processing or text recognition fails
    func recognizeText(from imageData: Data, tagNames: Set<String> = []) async throws -> OCRResult {
        guard let image = UIImage(data: imageData) else {
            throw VisionOCRError.imageEncodingFailed
        }

        guard let cgImage = image.cgImage else {
            throw VisionOCRError.imageEncodingFailed
        }

        let text = try await performOCR(on: cgImage)

        guard !text.isEmpty else {
            throw VisionOCRError.emptyResponse
        }

        // Check if any tags need structured extraction
        let extractionTags = tagNames.intersection(["Contact", "Event", "Receipt", "To-Do"])

        var contact: ContactExtraction?
        var event: EventExtraction?
        var receipt: ReceiptExtraction?
        var todo: TodoExtraction?

        if !extractionTags.isEmpty {
            // Perform on-device structured extraction
            if extractionTags.contains("Contact") {
                contact = await extractContact(from: text)
            }
            if extractionTags.contains("Event") {
                event = await extractEvent(from: text)
            }
            if extractionTags.contains("Receipt") {
                receipt = await extractReceipt(from: text)
            }
            if extractionTags.contains("To-Do") {
                todo = await extractTodo(from: text)
            }
        }

        logger.info("OCR complete: \(text.count) chars, contact=\(contact != nil), event=\(event != nil), receipt=\(receipt != nil), todo=\(todo != nil)")
        return OCRResult(text: text, contact: contact, event: event, receipt: receipt, todo: todo)
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
        let prompt = """
        Extract event information from the following text. Only include fields that are clearly visible.

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
                currency: r.currency,
                items: r.items?.map { ReceiptItem(name: $0.name, quantity: $0.quantity, price: $0.price) }
            )
        } catch {
            logger.warning("Receipt extraction failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// Extracts to-do items from OCR text using on-device AI.
    /// - Parameter text: OCR text to analyze
    /// - Returns: TodoExtraction if successful, nil if extraction fails
    private func extractTodo(from text: String) async -> TodoExtraction? {
        let prompt = """
        Extract to-do items from the following text. Each task as a separate entry.

        ---
        \(String(text.prefix(2000)))
        ---
        """

        do {
            let session = LanguageModelSession()
            let response = try await session.respond(
                to: prompt,
                generating: ExtractedTodo.self
            )
            let items = response.content.items?.map {
                TodoItem(title: $0.title, dueDate: $0.dueDate, priority: $0.priority, notes: $0.notes)
            }
            logger.info("Todo extraction: \(items?.count ?? 0) items")
            return TodoExtraction(items: items)
        } catch {
            logger.warning("Todo extraction failed: \(error.localizedDescription)")
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

    @Guide(description: "Date in ISO 8601 format")
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

    @Guide(description: "Line items on the receipt")
    var items: [ExtractedReceiptItem]?
}

@Generable(description: "Receipt line item")
private struct ExtractedReceiptItem {
    @Guide(description: "Item name")
    var name: String?

    @Guide(description: "Quantity")
    var quantity: Int?

    @Guide(description: "Price")
    var price: String?
}

@Generable(description: "To-do items extracted from text")
private struct ExtractedTodo {
    @Guide(description: "List of tasks")
    var items: [ExtractedTodoItem]?
}

@Generable(description: "A single to-do item")
private struct ExtractedTodoItem {
    @Guide(description: "Task description")
    var title: String?

    @Guide(description: "Due date in ISO 8601 if visible")
    var dueDate: String?

    @Guide(description: "Priority: high, medium, or low if indicated")
    var priority: String?

    @Guide(description: "Additional context")
    var notes: String?
}
