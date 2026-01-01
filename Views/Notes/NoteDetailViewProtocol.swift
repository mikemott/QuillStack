//
//  NoteDetailViewProtocol.swift
//  QuillStack
//
//  Architecture refactoring Phase 3: Common interface for all detail views.
//  Provides shared functionality and default implementations.
//

import SwiftUI
import UIKit

/// Protocol defining the common interface for all note detail views.
/// Conforming views gain access to default implementations for common operations.
///
/// Usage:
/// ```swift
/// struct TodoDetailView: View, NoteDetailViewProtocol {
///     @ObservedObject var note: Note
///
///     var body: some View {
///         // Your view implementation
///     }
///
///     func saveChanges() {
///         // Type-specific save logic
///     }
/// }
/// ```
protocol NoteDetailViewProtocol: View {
    /// The note being displayed/edited
    var note: Note { get }

    /// Persists changes to Core Data
    func saveChanges()

    /// Copies content to system clipboard
    func copyToClipboard()

    /// Presents system share sheet
    func shareContent()

    /// Returns the content to be shared/copied (override for type-specific formatting)
    var shareableContent: String { get }
}

// MARK: - Default Implementations

extension NoteDetailViewProtocol {
    /// Default clipboard implementation - copies note content
    func copyToClipboard() {
        UIPasteboard.general.string = shareableContent
    }

    /// Default share implementation - presents UIActivityViewController
    func shareContent() {
        let activityVC = UIActivityViewController(
            activityItems: [shareableContent],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }

    /// Default shareable content - the note's raw content
    var shareableContent: String {
        note.content
    }
}
