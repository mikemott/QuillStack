import SwiftData
import Foundation

@MainActor
final class CaptureProcessor {
    private let ocrService = OCRService()

    func process(_ capture: Capture, in context: ModelContext) {
        capture.isProcessingOCR = true

        let imageSnapshots = capture.sortedImages.map {
            ImageSnapshot(id: $0.persistentModelID, data: $0.imageData)
        }
        let captureID = capture.persistentModelID

        Task { @MainActor in
            var pageTexts: [String] = []
            var title: String?

            for (index, snapshot) in imageSnapshots.enumerated() {
                let text = await ocrService.recognizeText(in: snapshot.data)

                if let image = context.model(for: snapshot.id) as? CaptureImage {
                    image.ocrText = text
                }

                if let text { pageTexts.append(text) }

                if index == 0 {
                    title = await ocrService.extractTitle(in: snapshot.data)
                }
            }

            if let capture = context.model(for: captureID) as? Capture {
                capture.ocrText = pageTexts.isEmpty ? nil : pageTexts.joined(separator: "\n")
                capture.extractedTitle = title
                capture.isProcessingOCR = false
            }
            try? context.save()
        }
    }
}

private struct ImageSnapshot: Sendable {
    let id: PersistentIdentifier
    let data: Data
}
