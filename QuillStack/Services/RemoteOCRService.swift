import Foundation
import UIKit
import os

actor RemoteOCRService {
    static let shared = RemoteOCRService()

    private let logger = Logger(subsystem: "com.quillstack", category: "RemoteOCR")
    private var remoteHost: String

    init(remoteHost: String = "") {
        self.remoteHost = remoteHost
    }

    func setRemoteHost(_ host: String) {
        remoteHost = host
    }

    func checkAvailability() async -> Bool {
        guard !remoteHost.isEmpty else { return false }

        let url = URL(string: "http://\(remoteHost):11434/api/tags")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 3

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let available = (response as? HTTPURLResponse)?.statusCode == 200
            logger.debug("Remote server availability: \(available)")
            return available
        } catch {
            logger.debug("Remote server unreachable: \(error.localizedDescription)")
            return false
        }
    }

    func recognizeText(from imageData: Data) async throws -> String {
        guard !remoteHost.isEmpty else {
            throw RemoteOCRError.notConfigured
        }

        guard let image = UIImage(data: imageData),
              let base64 = image.toBase64JPEG(quality: 0.8) else {
            throw RemoteOCRError.imageEncodingFailed
        }

        let url = URL(string: "http://\(remoteHost):11434/api/generate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": "qwen3.5-vl:9b",
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

        logger.info("Sending OCR request to remote server")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RemoteOCRError.invalidResponse
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("OCR request failed with status: \(httpResponse.statusCode)")
            throw RemoteOCRError.serverError(httpResponse.statusCode)
        }

        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let text = json?["response"] as? String, !text.isEmpty else {
            logger.error("Empty or invalid response from Ollama")
            throw RemoteOCRError.emptyResponse
        }

        logger.info("OCR completed successfully")
        return text
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
            "Remote server host not configured"
        case .imageEncodingFailed:
            "Failed to encode image for transmission"
        case .serverUnreachable:
            "Remote server is unreachable"
        case .serverError(let code):
            "Server returned error code \(code)"
        case .invalidResponse:
            "Invalid response from server"
        case .emptyResponse:
            "Server returned empty response"
        }
    }
}
