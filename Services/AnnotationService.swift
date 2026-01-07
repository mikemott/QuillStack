//
//  AnnotationService.swift
//  QuillStack
//
//  Created on 2026-01-07.
//

import Foundation
import PencilKit
import CoreData
import UIKit
import os.log

// MARK: - Annotation Service Protocol

/// Protocol for annotation management operations.
/// Conforms to Sendable for concurrency safety.
protocol AnnotationServiceProtocol: Sendable {
    /// Save annotation drawing for a note
    func saveAnnotation(for note: Note, drawing: PKDrawing) async throws

    /// Load annotation drawing for a note
    func loadAnnotation(for note: Note) async throws -> PKDrawing?

    /// Delete annotation for a note
    func deleteAnnotation(for note: Note) async throws

    /// Export note with annotations composited as a single image
    func exportAnnotatedImage(note: Note, drawing: PKDrawing) async throws -> UIImage
}

// MARK: - Annotation Service

/// Service for managing PencilKit annotations on notes.
/// Handles saving, loading, and exporting annotations.
@MainActor
final class AnnotationService: AnnotationServiceProtocol {
    static let shared = AnnotationService()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "Annotation")

    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = CoreDataStack.shared.context) {
        self.context = context
    }

    // MARK: - Save Annotation

    nonisolated func saveAnnotation(for note: Note, drawing: PKDrawing) async throws {
        try await MainActor.run {
            do {
                let data = drawing.dataRepresentation()
                note.annotationData = data
                note.hasAnnotations = !drawing.strokes.isEmpty
                note.updatedAt = Date()

                try context.save()
                Self.logger.info("Saved annotation for note \(note.id)")
            } catch {
                Self.logger.error("Failed to save annotation: \(error.localizedDescription)")
                throw AnnotationError.saveFailed(error)
            }
        }
    }

    // MARK: - Load Annotation

    nonisolated func loadAnnotation(for note: Note) async throws -> PKDrawing? {
        try await MainActor.run {
            guard let data = note.annotationData else {
                return nil
            }

            do {
                let drawing = try PKDrawing(data: data)
                Self.logger.info("Loaded annotation for note \(note.id)")
                return drawing
            } catch {
                Self.logger.error("Failed to load annotation: \(error.localizedDescription)")
                throw AnnotationError.loadFailed(error)
            }
        }
    }

    // MARK: - Delete Annotation

    nonisolated func deleteAnnotation(for note: Note) async throws {
        try await MainActor.run {
            do {
                note.annotationData = nil
                note.hasAnnotations = false
                note.updatedAt = Date()

                try context.save()
                Self.logger.info("Deleted annotation for note \(note.id)")
            } catch {
                Self.logger.error("Failed to delete annotation: \(error.localizedDescription)")
                throw AnnotationError.deleteFailed(error)
            }
        }
    }

    // MARK: - Export Annotated Image

    nonisolated func exportAnnotatedImage(note: Note, drawing: PKDrawing) async throws -> UIImage {
        try await MainActor.run {
            // Get the original image
            guard let imageData = note.originalImageData,
                  let originalImage = UIImage(data: imageData) else {
                Self.logger.error("No original image found for note \(note.id)")
                throw AnnotationError.noOriginalImage
            }

            // Create a canvas to composite the image and drawing
            let size = originalImage.size
            let format = UIGraphicsImageRendererFormat()
            format.scale = originalImage.scale
            format.opaque = false

            let renderer = UIGraphicsImageRenderer(size: size, format: format)

            let compositeImage = renderer.image { context in
                // Draw the original image
                originalImage.draw(at: .zero)

                // Draw the annotation on top
                let cgContext = context.cgContext
                drawing.image(from: CGRect(origin: .zero, size: size), scale: originalImage.scale)
                    .draw(at: .zero)
            }

            Self.logger.info("Exported annotated image for note \(note.id)")
            return compositeImage
        }
    }
}

// MARK: - Annotation Errors

enum AnnotationError: LocalizedError {
    case saveFailed(Error)
    case loadFailed(Error)
    case deleteFailed(Error)
    case noOriginalImage

    var errorDescription: String? {
        switch self {
        case .saveFailed(let error):
            return "Failed to save annotation: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load annotation: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete annotation: \(error.localizedDescription)"
        case .noOriginalImage:
            return "No original image found for annotation export"
        }
    }
}
