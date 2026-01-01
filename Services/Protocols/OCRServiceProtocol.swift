//
//  OCRServiceProtocol.swift
//  QuillStack
//
//  Architecture refactoring: protocol abstraction for OCR service.
//  Enables dependency injection and testability.
//

import UIKit

/// Protocol defining OCR service capabilities.
/// Implement this protocol to provide alternative OCR implementations or mocks for testing.
protocol OCRServiceProtocol: Sendable {
    /// Recognizes text from an image with detailed word-level confidence.
    /// - Parameter image: The image to process
    /// - Returns: OCRResult containing recognized text and confidence data
    /// - Throws: OCRService.OCRError on failure
    func recognizeTextWithConfidence(from image: UIImage) async throws -> OCRResult

    /// Simple text recognition (returns just the text).
    /// - Parameter image: The image to process
    /// - Returns: Recognized text as a string
    /// - Throws: OCRService.OCRError on failure
    func recognizeText(from image: UIImage) async throws -> String

    /// Gets the average confidence score from OCR results.
    /// - Parameter image: The image to process
    /// - Returns: Average confidence as a float (0.0 to 1.0)
    /// - Throws: OCRService.OCRError on failure
    func getConfidenceScore(from image: UIImage) async throws -> Float

    /// Recognizes text from multiple images in parallel.
    /// - Parameter images: Array of images to process
    /// - Returns: Array of recognized text strings (same order as input)
    /// - Throws: OCRService.OCRError on failure
    func recognizeText(from images: [UIImage]) async throws -> [String]

    /// Advanced OCR with multiple preprocessing pipelines.
    /// Tries multiple approaches and returns the best result.
    /// - Parameter image: The image to process
    /// - Returns: OCRResult from the best preprocessing variant
    /// - Throws: OCRService.OCRError on failure
    func recognizeWithBestPreprocessing(from image: UIImage) async throws -> OCRResult
}

// MARK: - Default Implementation

extension OCRServiceProtocol {
    /// Default implementation delegates to recognizeTextWithConfidence
    func recognizeText(from image: UIImage) async throws -> String {
        let result = try await recognizeTextWithConfidence(from: image)
        return result.fullText
    }

    /// Default implementation delegates to recognizeTextWithConfidence
    func getConfidenceScore(from image: UIImage) async throws -> Float {
        let result = try await recognizeTextWithConfidence(from: image)
        return result.averageConfidence
    }
}
