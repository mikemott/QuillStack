import Foundation
import UIKit
import os

actor RemoteOCRService {
    static let shared = RemoteOCRService()

    private let logger = Logger(subsystem: "com.quillstack", category: "RemoteOCR")
    private var macMiniHost: String

    init(macMiniHost: String = "") {
        self.macMiniHost = macMiniHost
    }

    func setMacMiniHost(_ host: String) {
        macMiniHost = host
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
            let (_, response) = try await URLSession.shared.data(for: request)
            let available = (response as? HTTPURLResponse)?.statusCode == 200
            logger.debug("Mac Mini availability: \(available)")
            return available
        } catch {
            logger.debug("Mac Mini unreachable: \(error.localizedDescription)")
            return false
        }
    }

    func recognizeText(from imageData: Data) async throws -> String {
        guard !macMiniHost.isEmpty else {
            throw RemoteOCRError.notConfigured
        }

        guard let image = UIImage(data: imageData),
              let base64 = image.toBase64JPEG(quality: 0.8) else {
            throw RemoteOCRError.imageEncodingFailed
        }

        guard let url = buildURL(path: "/api/generate") else {
            throw RemoteOCRError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": "qwen3-vl:8b",
            "prompt": """
                Read this image carefully. Transcribe all visible text exactly as written, including:
                - Handwritten text (cursive or print)
                - Printed text
                - Numbers, dates, phone numbers, emails, URLs
                - Preserve formatting and structure

                Also describe:
                - What type of document or item this is
                - Any names, addresses, or contact information
                """,
            "images": [base64],
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
        guard let text = json?["response"] as? String, !text.isEmpty else {
            logger.error("Empty or invalid response from Ollama. JSON keys: \(json?.keys.joined(separator: ", ") ?? "none")")
            throw RemoteOCRError.emptyResponse
        }

        logger.info("OCR completed successfully, text length: \(text.count) chars")
        return text
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
