import Foundation
import UIKit
import os

actor RemoteOCRService {
    static let shared = RemoteOCRService()

    private let logger = Logger(subsystem: "com.quillstack", category: "RemoteOCR")
    private var macMiniHost: String
    private var modelName: String
    private var modelPreloaded = false

    init(macMiniHost: String = "", modelName: String = "chandra-ocr-2") {
        self.macMiniHost = macMiniHost
        self.modelName = modelName
    }

    func setMacMiniHost(_ host: String) {
        macMiniHost = host
        modelPreloaded = false
    }

    func setModelName(_ name: String) {
        modelName = name
        modelPreloaded = false
    }

    func checkAvailability() async -> Bool {
        guard !macMiniHost.isEmpty else { return false }

        guard let url = buildURL(path: "/api/tags") else {
            logger.debug("Invalid Mac Mini host: \(self.macMiniHost)")
            return false
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                logger.debug("Mac Mini unavailable")
                return false
            }

            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            let models = json?["models"] as? [[String: Any]] ?? []
            let hasModel = models.contains { ($0["name"] as? String)?.hasPrefix(modelName) == true }

            if !hasModel {
                logger.debug("Model \(self.modelName) not found on Mac Mini")
                return false
            }

            if !modelPreloaded {
                modelPreloaded = true
                Task { await preloadModel() }
            }
            return true
        } catch {
            logger.debug("Mac Mini unreachable: \(error.localizedDescription)")
            return false
        }
    }

    struct OCRResult {
        let text: String
        let title: String?
        let aiTags: [String]
        let contact: ContactExtraction?
        let event: EventExtraction?
        let receipt: ReceiptExtraction?
        let todo: TodoExtraction?
    }

    func recognizeText(from imageData: Data, tagNames: Set<String> = []) async throws -> OCRResult {
        guard !macMiniHost.isEmpty else {
            throw RemoteOCRError.notConfigured
        }

        guard let image = UIImage(data: imageData) else {
            throw RemoteOCRError.imageEncodingFailed
        }

        // Downscale for OCR — full resolution is unnecessary and slow
        let maxDimension: CGFloat = 1536
        let scale = min(maxDimension / max(image.size.width, image.size.height), 1.0)
        let scaledImage: UIImage
        if scale < 1.0 {
            let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            let renderer = UIGraphicsImageRenderer(size: newSize)
            scaledImage = renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        } else {
            scaledImage = image
        }

        guard let base64 = scaledImage.toBase64JPEG(quality: 0.7) else {
            throw RemoteOCRError.imageEncodingFailed
        }

        guard let url = buildURL(path: "/api/generate") else {
            throw RemoteOCRError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let body: [String: Any] = [
            "model": modelName,
            "prompt": buildPrompt(tagNames: tagNames),
            "images": [base64],
            "format": "json",
            "stream": false
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        logger.info("Sending OCR request to Mac Mini")

        let (data, response) = try await URLSession.shared.data(for: request)

        logger.info("Received response from Mac Mini, parsing...")

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteOCRError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("OCR request failed with status: \(httpResponse.statusCode)")
            throw RemoteOCRError.serverError(httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let responseText = json?["response"] as? String
        let thinkingText = json?["thinking"] as? String

        // Parse structured JSON from response
        var parsed: [String: Any]?
        for candidate in [responseText, thinkingText] {
            guard let candidate, !candidate.isEmpty else { continue }
            // Strip outer markdown code fences if present
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned: String
            if trimmed.hasPrefix("```") && trimmed.hasSuffix("```") {
                cleaned = trimmed
                    .replacingOccurrences(
                        of: #"^```(?:json)?\s*|\s*```$"#,
                        with: "",
                        options: .regularExpression
                    )
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                cleaned = trimmed
            }
            guard let candidateData = cleaned.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: candidateData) as? [String: Any] else {
                continue
            }
            parsed = obj
            break
        }

        guard let parsed else {
            logger.error("Empty or unparseable response from Ollama")
            throw RemoteOCRError.emptyResponse
        }

        logger.info("Ollama response keys: \(Array(parsed.keys).sorted())")
        if !tagNames.isEmpty {
            logger.info("Requested extractions for tags: \(tagNames.sorted())")
        }

        let text = parsed["text"] as? String ?? responseText ?? ""
        let tags = parsed["tags"] as? [String] ?? []
        let title = parsed["title"] as? String

        guard !text.isEmpty else {
            throw RemoteOCRError.emptyResponse
        }

        // Parse tag-specific extractions
        var contact: ContactExtraction?
        if let c = parsed["contact"] as? [String: Any] {
            contact = ContactExtraction(
                name: c["name"] as? String, phone: c["phone"] as? String,
                email: c["email"] as? String, company: c["company"] as? String,
                address: c["address"] as? String, jobTitle: c["jobTitle"] as? String,
                url: c["url"] as? String
            )
        }

        var event: EventExtraction?
        if let e = parsed["event"] as? [String: Any] {
            event = EventExtraction(
                title: e["title"] as? String, date: e["date"] as? String,
                time: e["time"] as? String, endTime: e["endTime"] as? String,
                location: e["location"] as? String, description: e["description"] as? String
            )
        }

        var receipt: ReceiptExtraction?
        if let r = parsed["receipt"] as? [String: Any] {
            let items = (r["items"] as? [[String: Any]])?.map { item in
                ReceiptItem(
                    name: item["name"] as? String,
                    quantity: item["quantity"] as? Int,
                    price: item["price"] as? String
                )
            }
            receipt = ReceiptExtraction(
                vendor: r["vendor"] as? String, total: r["total"] as? String,
                date: r["date"] as? String, currency: r["currency"] as? String,
                items: items
            )
        }

        var todo: TodoExtraction?
        if let t = parsed["todo"] {
            var todoItems: [[String: Any]]?

            // Model may return {"items": [...]} or just [...]
            if let obj = t as? [String: Any] {
                todoItems = obj["items"] as? [[String: Any]]
            } else if let arr = t as? [[String: Any]] {
                todoItems = arr
            }

            if let todoItems {
                let items = todoItems.map { item in
                    TodoItem(
                        title: item["title"] as? String,
                        dueDate: item["dueDate"] as? String,
                        priority: item["priority"] as? String,
                        notes: item["notes"] as? String
                    )
                }
                todo = TodoExtraction(items: items)
            }
        }

        logger.info("OCR completed: \(text.count) chars, \(tags.count) tags, title=\(title ?? "none"), contact=\(contact != nil), event=\(event != nil), receipt=\(receipt != nil), todo=\(todo != nil)")
        return OCRResult(text: text, title: title, aiTags: tags, contact: contact, event: event, receipt: receipt, todo: todo)
    }

    func buildPrompt(tagNames: Set<String>) -> String {
        var sections: [String] = [
            """
            /no_think
            Read this image carefully and respond with a JSON object containing:

            1. "text": Transcribe ALL visible text exactly as written (handwritten, printed, numbers, dates, phone numbers, emails, URLs). Preserve formatting and structure.

            2. "tags": Up to 4 short tags describing the SUBJECT MATTER and TOPICS (not the physical format). Lowercase, 1-2 words each. Do not use tags like "handwritten", "notebook", "notes", or "page".

            3. "title": A short descriptive title, under 10 words.
            """
        ]

        var fieldNum = 4

        if tagNames.contains("Contact") {
            sections.append("""
            \(fieldNum). "contact": Extract contact information as a JSON object with fields: name, phone, email, company, address, jobTitle, url. Only include fields that are clearly visible.
            """)
            fieldNum += 1
        }

        if tagNames.contains("Event") {
            sections.append("""
            \(fieldNum). "event": Extract event information as a JSON object with fields: title, date (ISO 8601), time, endTime, location, description. Only include fields that are clearly visible.
            """)
            fieldNum += 1
        }

        if tagNames.contains("Receipt") {
            sections.append("""
            \(fieldNum). "receipt": Extract receipt information as a JSON object with fields: vendor, total, date (ISO 8601), currency, items (array of objects with name, quantity, price). Only include fields that are clearly visible.
            """)
            fieldNum += 1
        }

        if tagNames.contains("To-Do") {
            sections.append("""
            \(fieldNum). "todo": Extract to-do items as a JSON object with fields: \
            items (array of objects with title, dueDate (ISO 8601 if visible), \
            priority (high/medium/low if indicated), notes). Extract each task as a separate entry.
            """)
            fieldNum += 1
        }

        sections.append("Respond ONLY with the JSON object.")
        return sections.joined(separator: "\n\n")
    }

    private func preloadModel() async {
        guard let url = buildURL(path: "/api/generate") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 300

        let body: [String: Any] = ["model": modelName, "keep_alive": "10m"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        _ = try? await URLSession.shared.data(for: request)
        logger.info("Model preload requested")
    }

    private func buildURL(path: String) -> URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = macMiniHost
        components.port = 11434
        components.path = path
        return components.url
    }
}

enum RemoteOCRError: Error, LocalizedError {
    case notConfigured
    case imageEncodingFailed
    case serverUnreachable
    case serverError(Int)
    case invalidResponse
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            "Mac Mini host not configured"
        case .imageEncodingFailed:
            "Failed to encode image for transmission"
        case .serverUnreachable:
            "Mac Mini is unreachable"
        case .serverError(let code):
            "Server returned error code \(code)"
        case .invalidResponse:
            "Invalid response from server"
        case .emptyResponse:
            "Server returned empty response"
        }
    }
}
