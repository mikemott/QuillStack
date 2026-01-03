//
//  OCRService.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import UIKit
@preconcurrency import Vision
import Sentry

// MARK: - OCR Result Models

/// Represents a single recognized word with confidence
struct RecognizedWord: Identifiable, Codable, Sendable {
    nonisolated let id: UUID
    nonisolated let text: String
    nonisolated let confidence: Float
    nonisolated let alternatives: [String]
    nonisolated let boundingBox: CGRect?

    nonisolated init(text: String, confidence: Float, alternatives: [String] = [], boundingBox: CGRect? = nil) {
        self.id = UUID()
        self.text = text
        self.confidence = confidence
        self.alternatives = alternatives
        self.boundingBox = boundingBox
    }

    nonisolated var isLowConfidence: Bool {
        confidence < 0.7
    }

    nonisolated var isMediumConfidence: Bool {
        confidence >= 0.7 && confidence < 0.85
    }

    nonisolated var isHighConfidence: Bool {
        confidence >= 0.85
    }
}

/// Represents a line of recognized text
struct RecognizedLine: Identifiable, Codable, Sendable {
    nonisolated let id: UUID
    nonisolated let words: [RecognizedWord]
    nonisolated let fullText: String
    nonisolated let lineConfidence: Float

    nonisolated init(words: [RecognizedWord]) {
        self.id = UUID()
        self.words = words
        self.fullText = words.map { $0.text }.joined(separator: " ")
        self.lineConfidence = words.isEmpty ? 0 : words.reduce(0) { $0 + $1.confidence } / Float(words.count)
    }
}

/// Complete OCR result with detailed word-level data
struct OCRResult: Codable, Sendable {
    nonisolated let lines: [RecognizedLine]
    nonisolated let fullText: String
    nonisolated let averageConfidence: Float
    nonisolated let lowConfidenceWords: [RecognizedWord]

    nonisolated init(lines: [RecognizedLine]) {
        self.lines = lines
        self.fullText = lines.map { $0.fullText }.joined(separator: "\n")

        let allWords = lines.flatMap { $0.words }
        self.averageConfidence = allWords.isEmpty ? 0 : allWords.reduce(0) { $0 + $1.confidence } / Float(allWords.count)
        self.lowConfidenceWords = allWords.filter { $0.isLowConfidence }
    }
}

// MARK: - OCR Service

/// Vision framework-based OCR implementation.
/// Conforms to OCRServiceProtocol for dependency injection.
final class OCRService: OCRServiceProtocol, @unchecked Sendable {
    static let shared = OCRService()

    nonisolated enum OCRError: Error {
        case noTextDetected
        case processingFailed
        case lowConfidence
        case invalidImage
    }

    private let imageProcessor = ImageProcessor()

    // Common words in emails and handwritten notes to improve recognition
    private nonisolated let customVocabulary = [
        // Email-specific
        "To", "From", "Subject", "Dear", "Hi", "Hello", "Sincerely", "Regards",
        "Best", "Thanks", "Thank", "Please", "Reply", "Forward", "Sent", "Received",
        "gmail", "yahoo", "outlook", "hotmail", "icloud", "email", "mail",
        "@", ".com", ".org", ".net", ".edu",
        // Common handwriting misreads
        "the", "and", "that", "this", "with", "have", "from", "they", "been",
        "would", "could", "should", "which", "their", "there", "about",
        // Meeting-specific
        "Meeting", "Agenda", "Action", "Items", "Attendees", "Notes", "Minutes",
        "Discussion", "Decision", "Follow-up", "TODO", "ASAP", "FYI",
        // Todo-specific
        "task", "tasks", "todo", "done", "pending", "complete", "deadline"
    ]

    /// Recognizes text from an image with detailed word-level confidence
    func recognizeTextWithConfidence(from image: UIImage) async throws -> OCRResult {
        // Sentry: Start performance transaction for OCR
        let transaction = SentrySDK.startTransaction(
            name: "OCRService.recognizeTextWithConfidence",
            operation: "ocr.recognize"
        )
        transaction.setData(value: [
            "image_size": "\(Int(image.size.width))x\(Int(image.size.height))"
        ], key: "image_info")
        
        // Apply preprocessing pipeline for better OCR
        let preprocessSpan = transaction.startChild(
            operation: "image.preprocess",
            description: "Preprocess image for OCR"
        )
        let processedImage = imageProcessor.preprocessForOCR(image: image) ?? image
        preprocessSpan.finish()

        guard let cgImage = processedImage.cgImage else {
            transaction.finish(status: .invalidArgument)
            throw OCRError.invalidImage
        }

        // Perform OCR on background thread
        let ocrSpan = transaction.startChild(
            operation: "ocr.vision",
            description: "Vision framework OCR"
        )
        let result = try await Task.detached(priority: .userInitiated) {
            try self.performOCRSync(cgImage: cgImage)
        }.value
        
        ocrSpan.setData(value: [
            "text_length": result.fullText.count,
            "confidence": Int(result.averageConfidence * 100),
            "lines_count": result.lines.count,
            "low_confidence_words": result.lowConfidenceWords.count
        ], key: "ocr_result")
        ocrSpan.finish()

        transaction.setData(value: [
            "text_length": result.fullText.count,
            "confidence": Int(result.averageConfidence * 100)
        ], key: "result")
        transaction.finish(status: .ok)

        return result
    }

    /// Synchronous OCR helper - runs on background thread
    private nonisolated func performOCRSync(cgImage: CGImage) throws -> OCRResult {
        let request = VNRecognizeTextRequest()

        // Use latest revision for best accuracy
        if #available(iOS 16.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-GB"]

        // Add custom vocabulary to improve recognition of common words
        request.customWords = customVocabulary

        // Lower minimum text height for small handwriting
        request.minimumTextHeight = 0.01

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextDetected
        }

        var recognizedLines: [RecognizedLine] = []

        for observation in observations {
            // Get top candidate and alternatives
            let candidates = observation.topCandidates(5)
            guard let topCandidate = candidates.first else { continue }

            let lineText = topCandidate.string
            let lineConfidence = observation.confidence

            // Split into words and estimate per-word confidence
            let words = parseWordsFromLine(
                lineText: lineText,
                lineConfidence: lineConfidence,
                alternatives: candidates.dropFirst().map { $0.string }
            )

            if !words.isEmpty {
                recognizedLines.append(RecognizedLine(words: words))
            }
        }

        if recognizedLines.isEmpty {
            throw OCRError.lowConfidence
        }

        return OCRResult(lines: recognizedLines)
    }

    /// Parse words from a line and estimate per-word confidence
    nonisolated private func parseWordsFromLine(lineText: String, lineConfidence: Float, alternatives: [String]) -> [RecognizedWord] {
        let words = lineText.components(separatedBy: .whitespaces).filter { !$0.isEmpty }

        return words.enumerated().map { index, word in
            // Find alternatives for this word position from other candidates
            var wordAlternatives: [String] = []

            for altLine in alternatives {
                let altWords = altLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                if index < altWords.count && altWords[index] != word {
                    wordAlternatives.append(altWords[index])
                }
            }

            // Estimate word confidence based on:
            // 1. Line confidence
            // 2. Whether word appears consistently in alternatives
            // 3. Word characteristics (unusual characters, etc.)
            var wordConfidence = lineConfidence

            // Reduce confidence for words that differ in alternatives
            if !wordAlternatives.isEmpty {
                wordConfidence *= 0.85
            }

            // Reduce confidence for words with unusual patterns
            if word.contains(where: { !$0.isLetter && !$0.isNumber && !$0.isPunctuation }) {
                wordConfidence *= 0.9
            }

            // Reduce confidence for very short words (often misread)
            if word.count == 1 && !["I", "a", "A"].contains(word) {
                wordConfidence *= 0.8
            }

            return RecognizedWord(
                text: word,
                confidence: wordConfidence,
                alternatives: Array(Set(wordAlternatives)).prefix(3).map { String($0) }
            )
        }
    }

    /// Simple text recognition (backward compatible)
    func recognizeText(from image: UIImage) async throws -> String {
        let result = try await recognizeTextWithConfidence(from: image)
        return result.fullText
    }

    /// Gets the average confidence score from OCR results
    func getConfidenceScore(from image: UIImage) async throws -> Float {
        let result = try await recognizeTextWithConfidence(from: image)
        return result.averageConfidence
    }

    /// Recognizes text from multiple images in parallel
    func recognizeText(from images: [UIImage]) async throws -> [String] {
        try await withThrowingTaskGroup(of: (Int, String).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let text = try await self.recognizeText(from: image)
                    return (index, text)
                }
            }

            var results: [(Int, String)] = []
            for try await result in group {
                results.append(result)
            }

            return results.sorted(by: { $0.0 < $1.0 }).map { $0.1 }
        }
    }

    // MARK: - Advanced OCR with Multiple Preprocessing Pipelines

    /// Tries multiple preprocessing approaches and returns the best result
    /// Use this for difficult-to-read handwriting
    func recognizeWithBestPreprocessing(from image: UIImage) async throws -> OCRResult {
        // Generate multiple preprocessed variants
        let variants = generatePreprocessingVariants(from: image)

        var bestResult: OCRResult?
        var bestScore: Float = 0

        // Try OCR on each variant and keep the best result
        for variant in variants {
            do {
                let result = try await recognizeTextWithConfidenceRaw(from: variant)

                // Score based on confidence and text length (prefer more recognized text)
                let score = result.averageConfidence * Float(min(result.fullText.count, 500)) / 500.0

                if bestResult == nil || score > bestScore {
                    bestResult = result
                    bestScore = score
                }
            } catch {
                // Continue trying other variants
                continue
            }
        }

        guard let result = bestResult else {
            throw OCRError.noTextDetected
        }

        return result
    }

    /// Generates multiple preprocessed versions of the image
    private func generatePreprocessingVariants(from image: UIImage) -> [UIImage] {
        var variants: [UIImage] = []

        // 1. Standard preprocessing pipeline
        if let standard = imageProcessor.preprocessForOCR(image: image) {
            variants.append(standard)
        }

        // 2. Original with just scaling
        if let scaled = imageProcessor.scaleForOCR(image: image) {
            variants.append(scaled)
        }

        // 3. Binarized with lower threshold (captures lighter strokes)
        if let binarizedLow = imageProcessor.binarize(image: image, threshold: 0.35) {
            variants.append(binarizedLow)
        }

        // 4. Binarized with standard threshold
        if let binarizedMid = imageProcessor.binarize(image: image, threshold: 0.5) {
            variants.append(binarizedMid)
        }

        // 5. Binarized with higher threshold (for darker writing)
        if let binarizedHigh = imageProcessor.binarize(image: image, threshold: 0.65) {
            variants.append(binarizedHigh)
        }

        // 6. Grayscale only
        if let grayscale = imageProcessor.convertToGrayscale(image: image) {
            variants.append(grayscale)
        }

        // Fallback to original if no variants generated
        if variants.isEmpty {
            variants.append(image)
        }

        return variants
    }

    /// Internal OCR without preprocessing (used by multi-pipeline approach)
    private func recognizeTextWithConfidenceRaw(from image: UIImage) async throws -> OCRResult {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }

        // Perform OCR on background thread
        return try await Task.detached(priority: .userInitiated) {
            try self.performOCRRawSync(cgImage: cgImage)
        }.value
    }

    /// Synchronous OCR helper for raw processing - runs on background thread
    private nonisolated func performOCRRawSync(cgImage: CGImage) throws -> OCRResult {
        let request = VNRecognizeTextRequest()

        if #available(iOS 16.0, *) {
            request.revision = VNRecognizeTextRequestRevision3
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US", "en-GB"]
        request.customWords = customVocabulary
        request.minimumTextHeight = 0.01

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])

        guard let observations = request.results, !observations.isEmpty else {
            throw OCRError.noTextDetected
        }

        var recognizedLines: [RecognizedLine] = []

        for observation in observations {
            let candidates = observation.topCandidates(5)
            guard let topCandidate = candidates.first else { continue }

            let lineText = topCandidate.string
            let lineConfidence = observation.confidence

            let words = parseWordsFromLine(
                lineText: lineText,
                lineConfidence: lineConfidence,
                alternatives: candidates.dropFirst().map { $0.string }
            )

            if !words.isEmpty {
                recognizedLines.append(RecognizedLine(words: words))
            }
        }

        if recognizedLines.isEmpty {
            throw OCRError.lowConfidence
        }

        return OCRResult(lines: recognizedLines)
    }
}
