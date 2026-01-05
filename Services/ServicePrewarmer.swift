//
//  ServicePrewarmer.swift
//  QuillStack
//
//  Created on 2026-01-05.
//

import UIKit

/// Handles eager initialization of expensive services on a background thread to
/// prevent launch-time stalls the first time OCR runs.
enum ServicePrewarmer {
    private static var hasStartedWarmup = false
    private static let warmupLock = NSLock()

    /// Kicks off a one-time warm-up that instantiates heavy services off the
    /// main thread so they are ready when the user captures their first note.
    static func warmHeavyServices() {
        warmupLock.lock()
        guard !hasStartedWarmup else {
            warmupLock.unlock()
            return
        }

        hasStartedWarmup = true
        warmupLock.unlock()

        Task.detached(priority: .background) {
            await warmImagePipeline()
            await warmOCRPipeline()
        }
    }

    @Sendable
    private static func warmImagePipeline() async {
        let processor = ImageProcessor()
        let warmupImage = makeWarmupImage()

        _ = processor.preprocess(image: warmupImage)
        _ = processor.preprocessForOCR(image: warmupImage)
    }

    @Sendable
    private static func warmOCRPipeline() async {
        let service = OCRService.shared
        let warmupImage = makeWarmupImage()

        // We discard the result – the goal is to trigger Vision/CIContext setup
        _ = try? await service.recognizeTextWithConfidence(from: warmupImage)
    }

    private static func makeWarmupImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 80))
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: CGSize(width: 160, height: 80)))

            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center

            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24, weight: .medium),
                .foregroundColor: UIColor.black,
                .paragraphStyle: paragraph
            ]

            let text = "QUILL"
            let rect = CGRect(origin: .zero, size: CGSize(width: 160, height: 80))
            text.draw(in: rect.insetBy(dx: 10, dy: 10), withAttributes: attributes)
        }
    }
}
