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
    @MainActor private static var cachedWarmupImageData: Data?

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
            guard let warmupData = await MainActor.run(body: { warmupImageData() }) else {
                return
            }

            await warmImagePipeline(warmupData: warmupData)
            await warmOCRPipeline(warmupData: warmupData)
        }
    }

    @Sendable
    private static func warmImagePipeline(warmupData: Data) async {
        let processor = ImageProcessor()
        guard let warmupImage = imageFromWarmupData(warmupData) else { return }

        autoreleasepool {
            _ = processor.preprocess(image: warmupImage)
            _ = processor.preprocessForOCR(image: warmupImage)
        }
    }

    @Sendable
    private static func warmOCRPipeline(warmupData: Data) async {
        let service = OCRService.shared
        guard let warmupImage = imageFromWarmupData(warmupData) else { return }

        // We discard the result – the goal is to trigger Vision/CIContext setup
        // Note: Can't use autoreleasepool with async/await - the async operation manages its own resources
        _ = try? await service.recognizeTextWithConfidence(from: warmupImage)
    }

    @MainActor
    private static func warmupImageData() -> Data? {
        if let cachedWarmupImageData {
            return cachedWarmupImageData
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 160, height: 80))
        let image = renderer.image { context in
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

        let data = image.pngData()
        cachedWarmupImageData = data
        return data
    }

    private static func imageFromWarmupData(_ data: Data) -> UIImage? {
        UIImage(data: data)
    }
}
