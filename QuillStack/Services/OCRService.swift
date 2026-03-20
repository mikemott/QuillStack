import Vision
import UIKit

struct OCRResult: Sendable {
    let fullText: String?
    let title: String?
    let averageConfidence: Double?
}

actor OCRService {
    func recognizeText(in imageData: Data) async -> OCRResult {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else { return OCRResult(fullText: nil, title: nil, averageConfidence: nil) }

        return await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: OCRResult(fullText: nil, title: nil, averageConfidence: nil))
                    return
                }

                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")

                // Title: largest bounding box height = most prominent text
                let candidates = observations.compactMap { obs -> (String, CGFloat)? in
                    guard let text = obs.topCandidates(1).first?.string else { return nil }
                    return (text, obs.boundingBox.height)
                }
                let title = candidates.max(by: { $0.1 < $1.1 }).map { String($0.0.prefix(80)) }

                // Average confidence across all observations as handwriting proxy
                let confidences = observations.compactMap { $0.topCandidates(1).first?.confidence }
                let avgConfidence = confidences.isEmpty ? nil : Double(confidences.reduce(0, +)) / Double(confidences.count)

                continuation.resume(returning: OCRResult(
                    fullText: text.isEmpty ? nil : text,
                    title: title,
                    averageConfidence: avgConfidence.map { Double($0) }
                ))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }
}
