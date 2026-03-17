import Vision
import UIKit

actor OCRService {
    func recognizeText(in imageData: Data) async -> String? {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text.isEmpty ? nil : text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }

    func extractTitle(in imageData: Data) async -> String? {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Find the most prominent text: largest bounding box height
                let candidates = observations.compactMap { obs -> (String, CGFloat)? in
                    guard let text = obs.topCandidates(1).first?.string else { return nil }
                    return (text, obs.boundingBox.height)
                }

                if let largest = candidates.max(by: { $0.1 < $1.1 }) {
                    let title = String(largest.0.prefix(80))
                    continuation.resume(returning: title)
                } else if let first = candidates.first {
                    continuation.resume(returning: String(first.0.prefix(80)))
                } else {
                    continuation.resume(returning: nil)
                }
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}
