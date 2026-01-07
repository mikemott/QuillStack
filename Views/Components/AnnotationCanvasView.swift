//
//  AnnotationCanvasView.swift
//  QuillStack
//
//  Created on 2026-01-07.
//

import SwiftUI
import PencilKit

// MARK: - Annotation Canvas View

/// SwiftUI wrapper for PencilKit's PKCanvasView.
/// Provides annotation capabilities for notes with Apple Pencil or finger drawing.
struct AnnotationCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var tool: PKInkingTool

    let isDrawingEnabled: Bool
    let onDrawingChanged: ((PKDrawing) -> Void)?

    init(
        drawing: Binding<PKDrawing>,
        tool: Binding<PKInkingTool>,
        isDrawingEnabled: Bool = true,
        onDrawingChanged: ((PKDrawing) -> Void)? = nil
    ) {
        self._drawing = drawing
        self._tool = tool
        self.isDrawingEnabled = isDrawingEnabled
        self.onDrawingChanged = onDrawingChanged
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvasView = PKCanvasView()

        // Configure canvas
        canvasView.drawing = drawing
        canvasView.tool = tool
        canvasView.drawingPolicy = .anyInput // Allow both Apple Pencil and finger
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false

        // Set delegate
        canvasView.delegate = context.coordinator

        return canvasView
    }

    func updateUIView(_ canvasView: PKCanvasView, context: Context) {
        // Update drawing if it changed externally
        if canvasView.drawing != drawing {
            canvasView.drawing = drawing
        }

        // Update tool
        canvasView.tool = tool

        // Update drawing enabled state
        canvasView.isUserInteractionEnabled = isDrawingEnabled
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: AnnotationCanvasView

        init(_ parent: AnnotationCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            // Update binding
            parent.drawing = canvasView.drawing

            // Notify callback
            parent.onDrawingChanged?(canvasView.drawing)
        }
    }
}

// MARK: - Annotation Tools

/// Predefined annotation tools for QuillStack branding
struct AnnotationTools {
    /// Black pen for general drawing
    static let blackPen = PKInkingTool(.pen, color: .black, width: 2.0)

    /// Red pen for highlighting important items
    static let redPen = PKInkingTool(.pen, color: .red, width: 2.0)

    /// Forest green pen (brand color)
    static let forestPen = PKInkingTool(.pen, color: UIColor(red: 0.133, green: 0.267, blue: 0.2, alpha: 1.0), width: 2.0)

    /// Yellow highlighter
    static let yellowHighlighter = PKInkingTool(.marker, color: UIColor.yellow.withAlphaComponent(0.4), width: 20.0)

    /// Default tool (black pen)
    static let `default` = blackPen
}

// MARK: - Annotation Mode View

/// Full-screen annotation mode view with tool picker and controls
struct AnnotationModeView: View {
    @Environment(\.dismiss) private var dismiss

    let note: Note
    @Binding var drawing: PKDrawing
    @State private var currentTool: PKInkingTool = AnnotationTools.default
    @State private var showingToolPicker = true
    @State private var hasChanges = false

    let onSave: (PKDrawing) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            // Background image (original note)
            if let imageData = note.originalImageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Canvas overlay
            AnnotationCanvasView(
                drawing: $drawing,
                tool: $currentTool,
                isDrawingEnabled: true,
                onDrawingChanged: { _ in
                    hasChanges = true
                }
            )
            .ignoresSafeArea()

            // Tool picker overlay
            VStack {
                Spacer()

                HStack(spacing: 20) {
                    // Tool buttons
                    ToolButton(
                        icon: "pencil",
                        label: "Black",
                        isSelected: currentTool == AnnotationTools.blackPen
                    ) {
                        currentTool = AnnotationTools.blackPen
                    }

                    ToolButton(
                        icon: "pencil",
                        label: "Red",
                        isSelected: currentTool == AnnotationTools.redPen,
                        color: .red
                    ) {
                        currentTool = AnnotationTools.redPen
                    }

                    ToolButton(
                        icon: "pencil",
                        label: "Green",
                        isSelected: currentTool == AnnotationTools.forestPen,
                        color: .forestDark
                    ) {
                        currentTool = AnnotationTools.forestPen
                    }

                    ToolButton(
                        icon: "highlighter",
                        label: "Highlight",
                        isSelected: currentTool == AnnotationTools.yellowHighlighter,
                        color: .yellow
                    ) {
                        currentTool = AnnotationTools.yellowHighlighter
                    }

                    Divider()
                        .frame(height: 40)

                    // Clear all button
                    Button {
                        drawing = PKDrawing()
                        hasChanges = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.title2)
                            Text("Clear")
                                .font(.caption2)
                        }
                    }
                    .foregroundColor(.textDark)
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.bottom, 20)
            }

            // Top controls
            VStack {
                HStack {
                    Button {
                        if hasChanges {
                            onCancel()
                        }
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundColor(.textDark)
                    }

                    Spacer()

                    Text("Annotate")
                        .font(.headline)
                        .foregroundColor(.textDark)

                    Spacer()

                    Button {
                        onSave(drawing)
                        dismiss()
                    } label: {
                        Text("Save")
                            .fontWeight(.semibold)
                            .foregroundColor(.forestDark)
                    }
                }
                .padding()
                .background(.regularMaterial)

                Spacer()
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Tool Button

private struct ToolButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    var color: Color = .textDark
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(label)
                    .font(.caption2)
            }
            .foregroundColor(isSelected ? color : .textDark.opacity(0.6))
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                isSelected ? color.opacity(0.1) : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

#Preview {
    // Preview with a sample note
    let context = CoreDataStack.preview.context
    let note = Note.create(in: context, content: "Sample note for annotation preview")

    AnnotationModeView(
        note: note,
        drawing: .constant(PKDrawing()),
        onSave: { _ in },
        onCancel: { }
    )
}
