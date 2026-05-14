import Foundation
import UIKit
import os

actor DatalabOCRService {
    static let shared = DatalabOCRService()

    private let logger = Logger(subsystem: "com.quillstack", category: "DatalabOCR")
    private var apiKey: String = ""

    private let baseURL = "https://www.datalab.to/api/v1"
    private let pollInterval: TimeInterval = 2.0
    private let maxPollAttempts = 90

    func setAPIKey(_ key: String) {
        guard !key.isEmpty, !key.hasPrefix("$(") else { return }
        apiKey = key
    }

    var isConfigured: Bool { !apiKey.isEmpty }

    // MARK: - OCR Result

    struct OCRResult: Sendable {
        let text: String
        let contact: ContactExtraction?
        let event: EventExtraction?
        let receipt: ReceiptExtraction?
        let todo: TodoExtraction?
    }

    // MARK: - Public API

    func recognizeText(from imageData: Data, tagNames: Set<String> = []) async throws -> OCRResult {
        guard !apiKey.isEmpty else {
            throw DatalabOCRError.notConfigured
        }

        guard let image = UIImage(data: imageData) else {
            throw DatalabOCRError.imageEncodingFailed
        }

        let maxDimension: CGFloat = 1536
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)
        let processedImage: UIImage
        if scale < 1.0 {
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            processedImage = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            processedImage = image
        }

        guard let jpegData = processedImage.jpegData(compressionQuality: 0.7) else {
            throw DatalabOCRError.imageEncodingFailed
        }

        // Check if any tags need structured extraction
        let extractionTags = tagNames.intersection(["Contact", "Event", "Receipt", "To-Do"])

        let response: [String: Any]
        if !extractionTags.isEmpty {
            // /extract: OCR + structured extraction in one call
            let schema = buildSchema(tagNames: extractionTags)
            let checkURL = try await submitExtract(jpegData: jpegData, schema: schema)
            response = try await pollForResult(checkURL: checkURL)
        } else {
            // /convert: OCR only, no extraction needed
            let checkURL = try await submitConvert(jpegData: jpegData)
            response = try await pollForResult(checkURL: checkURL)
        }

        let markdown = response["markdown"] as? String ?? ""
        guard !markdown.isEmpty else {
            throw DatalabOCRError.emptyResponse
        }

        // Parse structured extractions if present
        var contact: ContactExtraction?
        var event: EventExtraction?
        var receipt: ReceiptExtraction?
        var todo: TodoExtraction?

        if let extraction = parseExtractionSchemaJSON(response) {
            contact = parseContact(extraction)
            event = parseEvent(extraction)
            receipt = parseReceipt(extraction)
            todo = parseTodo(extraction)
        }

        logger.info("OCR complete: \(markdown.count) chars, contact=\(contact != nil), event=\(event != nil), receipt=\(receipt != nil), todo=\(todo != nil)")
        return OCRResult(text: markdown, contact: contact, event: event, receipt: receipt, todo: todo)
    }

    func checkAvailability() async -> Bool {
        guard !apiKey.isEmpty else { return false }

        guard let url = URL(string: baseURL) else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 5

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (200..<300).contains(status)
        } catch {
            logger.debug("Datalab API unreachable: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Submit Convert

    private func submitConvert(jpegData: Data) async throws -> URL {
        guard let url = URL(string: "\(baseURL)/convert") else {
            throw DatalabOCRError.invalidResponse
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 30

        var body = Data()
        body.appendMultipart(boundary: boundary, name: "file", filename: "capture.jpg", mimeType: "image/jpeg", data: jpegData)
        body.appendMultipartField(boundary: boundary, name: "output_format", value: "markdown")
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        logger.info("Submitting convert to Datalab API")
        return try await submitAndGetCheckURL(request: request)
    }

    // MARK: - Submit Extract

    private func submitExtract(jpegData: Data, schema: [String: Any]) async throws -> URL {
        guard let url = URL(string: "\(baseURL)/extract") else {
            throw DatalabOCRError.invalidResponse
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 30

        var body = Data()
        body.appendMultipart(boundary: boundary, name: "file", filename: "capture.jpg", mimeType: "image/jpeg", data: jpegData)
        body.appendMultipartField(boundary: boundary, name: "output_format", value: "markdown")

        let schemaJSON = try JSONSerialization.data(withJSONObject: schema)
        if let schemaString = String(data: schemaJSON, encoding: .utf8) {
            body.appendMultipartField(boundary: boundary, name: "page_schema", value: schemaString)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        logger.info("Submitting extract to Datalab API")
        return try await submitAndGetCheckURL(request: request)
    }

    // MARK: - Shared Submit

    private func submitAndGetCheckURL(request: URLRequest) async throws -> URL {
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DatalabOCRError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("Submit failed: HTTP \(httpResponse.statusCode)")
            throw DatalabOCRError.serverError(httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let checkURLString = json?["request_check_url"] as? String,
              let checkURL = URL(string: checkURLString) else {
            throw DatalabOCRError.invalidResponse
        }

        logger.info("Submitted, polling: \(checkURLString)")
        return checkURL
    }

    // MARK: - Poll

    private func pollForResult(checkURL: URL) async throws -> [String: Any] {
        var request = URLRequest(url: checkURL)
        request.setValue(apiKey, forHTTPHeaderField: "X-API-Key")
        request.timeoutInterval = 10

        for attempt in 1...maxPollAttempts {
            try await Task.sleep(for: .seconds(pollInterval))

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else { continue }

            // Fail fast on terminal errors (bad key, server failure, etc.)
            if (400..<600).contains(httpResponse.statusCode) {
                throw DatalabOCRError.serverError(httpResponse.statusCode)
            }

            guard httpResponse.statusCode == 200 else { continue }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }

            let status = json["status"] as? String

            if status == "complete" {
                guard json["success"] as? Bool == true else {
                    let error = json["error"] as? String ?? "Unknown error"
                    throw DatalabOCRError.extractionFailed(error)
                }
                logger.info("Complete after \(attempt) polls")
                return json
            }

            if status == "failed" {
                let error = json["error"] as? String ?? "Processing failed"
                throw DatalabOCRError.extractionFailed(error)
            }
        }

        throw DatalabOCRError.timeout
    }

    // MARK: - Extraction Response Parsing

    /// Datalab returns `extraction_schema_json` as a JSON-encoded string, not a dictionary.
    /// This helper double-parses it: first extracts the string, then decodes the JSON within.
    private func parseExtractionSchemaJSON(_ response: [String: Any]) -> [String: Any]? {
        // Try as dictionary first (in case Datalab changes the format)
        if let dict = response["extraction_schema_json"] as? [String: Any] {
            return dict
        }

        // It's a JSON string — double-parse
        guard let jsonString = response["extraction_schema_json"] as? String,
              let data = jsonString.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        return parsed
    }

    // MARK: - Extraction Parsers

    private func parseContact(_ extraction: [String: Any]) -> ContactExtraction? {
        guard let c = extraction["contact"] as? [String: Any] else { return nil }
        return ContactExtraction(
            name: c["name"] as? String, phone: c["phone"] as? String,
            email: c["email"] as? String, company: c["company"] as? String,
            address: c["address"] as? String, jobTitle: c["jobTitle"] as? String,
            url: c["url"] as? String
        )
    }

    private func parseEvent(_ extraction: [String: Any]) -> EventExtraction? {
        guard let e = extraction["event"] as? [String: Any] else { return nil }
        return EventExtraction(
            title: e["title"] as? String, date: e["date"] as? String,
            time: e["time"] as? String, endTime: e["endTime"] as? String,
            location: e["location"] as? String, description: e["description"] as? String
        )
    }

    private func parseReceipt(_ extraction: [String: Any]) -> ReceiptExtraction? {
        guard let r = extraction["receipt"] as? [String: Any] else { return nil }
        let items = (r["items"] as? [[String: Any]])?.map { item in
            ReceiptItem(
                name: item["name"] as? String,
                quantity: item["quantity"] as? Int,
                price: item["price"] as? String
            )
        }
        return ReceiptExtraction(
            vendor: r["vendor"] as? String, total: r["total"] as? String,
            date: r["date"] as? String, currency: r["currency"] as? String,
            items: items
        )
    }

    private func parseTodo(_ extraction: [String: Any]) -> TodoExtraction? {
        guard let t = extraction["todo"] else { return nil }
        var todoItems: [[String: Any]]?
        if let obj = t as? [String: Any] {
            todoItems = obj["items"] as? [[String: Any]]
        } else if let arr = t as? [[String: Any]] {
            todoItems = arr
        }
        guard let todoItems else { return nil }
        let items = todoItems.map { item in
            TodoItem(
                title: item["title"] as? String,
                dueDate: item["dueDate"] as? String,
                priority: item["priority"] as? String,
                notes: item["notes"] as? String
            )
        }
        return TodoExtraction(items: items)
    }

    // MARK: - Schema Builder

    nonisolated func buildSchema(tagNames: Set<String>) -> [String: Any] {
        var properties: [String: Any] = [:]
        var required: [String] = []

        if tagNames.contains("Contact") {
            properties["contact"] = [
                "type": "object",
                "description": "Extract contact information. Only include fields that are clearly visible.",
                "properties": [
                    "name": ["type": "string", "description": "Full name"],
                    "phone": ["type": "string", "description": "Phone number"],
                    "email": ["type": "string", "description": "Email address"],
                    "company": ["type": "string", "description": "Company or organization"],
                    "address": ["type": "string", "description": "Physical address"],
                    "jobTitle": ["type": "string", "description": "Job title or role"],
                    "url": ["type": "string", "description": "Website URL"]
                ]
            ]
            required.append("contact")
        }

        if tagNames.contains("Event") {
            properties["event"] = [
                "type": "object",
                "description": "Extract event information. Only include fields that are clearly visible.",
                "properties": [
                    "title": ["type": "string", "description": "Event title"],
                    "date": ["type": "string", "description": "Date in ISO 8601 format"],
                    "time": ["type": "string", "description": "Start time"],
                    "endTime": ["type": "string", "description": "End time"],
                    "location": ["type": "string", "description": "Venue or address"],
                    "description": ["type": "string", "description": "Event description"]
                ]
            ]
            required.append("event")
        }

        if tagNames.contains("Receipt") {
            properties["receipt"] = [
                "type": "object",
                "description": "Extract receipt information. Only include fields that are clearly visible.",
                "properties": [
                    "vendor": ["type": "string", "description": "Store or business name"],
                    "total": ["type": "string", "description": "Total amount"],
                    "date": ["type": "string", "description": "Transaction date in ISO 8601"],
                    "currency": ["type": "string", "description": "Currency code (USD, EUR, etc.)"],
                    "items": [
                        "type": "array",
                        "description": "Line items on the receipt",
                        "items": [
                            "type": "object",
                            "properties": [
                                "name": ["type": "string"],
                                "quantity": ["type": "integer"],
                                "price": ["type": "string"]
                            ]
                        ]
                    ]
                ]
            ]
            required.append("receipt")
        }

        if tagNames.contains("To-Do") {
            properties["todo"] = [
                "type": "object",
                "description": "Extract to-do items. Each task as a separate entry.",
                "properties": [
                    "items": [
                        "type": "array",
                        "items": [
                            "type": "object",
                            "properties": [
                                "title": ["type": "string", "description": "Task description"],
                                "dueDate": ["type": "string", "description": "Due date in ISO 8601 if visible"],
                                "priority": ["type": "string", "description": "high, medium, or low if indicated"],
                                "notes": ["type": "string", "description": "Additional context"]
                            ]
                        ]
                    ]
                ]
            ]
            required.append("todo")
        }

        return [
            "type": "object",
            "properties": properties,
            "required": required
        ]
    }
}

// MARK: - Errors

enum DatalabOCRError: Error, LocalizedError {
    case notConfigured
    case imageEncodingFailed
    case serverError(Int)
    case invalidResponse
    case emptyResponse
    case extractionFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Datalab API key not configured"
        case .imageEncodingFailed:
            "Failed to encode image for transmission"
        case .serverError(let code):
            "Server returned error code \(code)"
        case .invalidResponse:
            "Invalid response from server"
        case .emptyResponse:
            "Server returned empty response"
        case .extractionFailed(let message):
            "Extraction failed: \(message)"
        case .timeout:
            "Request timed out waiting for extraction"
        }
    }
}

// MARK: - Multipart Helpers

private extension Data {
    mutating func appendMultipart(boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        append(data)
        append("\r\n".data(using: .utf8)!)
    }

    mutating func appendMultipartField(boundary: String, name: String, value: String) {
        append("--\(boundary)\r\n".data(using: .utf8)!)
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        append(value.data(using: .utf8)!)
        append("\r\n".data(using: .utf8)!)
    }
}
