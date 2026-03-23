import Foundation
import UIKit
import os

actor RemoteOCRService {
    static let shared = RemoteOCRService()

    private let logger = Logger(subsystem: "com.quillstack", category: "RemoteOCR")
    private var macMiniHost: String
    private var modelName: String

    init(macMiniHost: String = "", modelName: String = "qwen3-vl:8b") {
        self.macMiniHost = macMiniHost
        self.modelName = modelName
    }

    func setMacMiniHost(_ host: String) {
        macMiniHost = host
    }

    func setModelName(_ name: String) {
        modelName = name
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

            // Preload the model so it's warm for OCR requests
            Task { await preloadModel() }
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
    }

    func recognizeText(from imageData: Data) async throws -> OCRResult {
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
            "prompt": """
                /no_think
                Read this image carefully and respond with a JSON object containing:

                1. "text": Transcribe ALL visible text exactly as written (handwritten, printed, numbers, dates, phone numbers, emails, URLs). Preserve formatting and structure.

                2. "tags": Up to 4 short tags describing the SUBJECT MATTER and TOPICS (not the physical format). Lowercase, 1-2 words each. Do not use tags like "handwritten", "notebook", "notes", or "page".

                3. "title": A short descriptive title, under 10 words.

                Respond ONLY with the JSON object.
                """,
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

        // Parse structured JSON from response or thinking field (Qwen3 thinking mode)
        var parsed: [String: Any]?
        for candidate in [responseText, thinkingText] {
            guard let candidate, !candidate.isEmpty,
                  let candidateData = candidate.data(using: .utf8),
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

        let text = parsed["text"] as? String ?? responseText ?? ""
        let tags = parsed["tags"] as? [String] ?? []
        let title = parsed["title"] as? String

        guard !text.isEmpty else {
            throw RemoteOCRError.emptyResponse
        }

        logger.info("OCR completed: \(text.count) chars, \(tags.count) tags, title=\(title ?? "none")")
        return OCRResult(text: text, title: title, aiTags: tags)
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
