//
//  SmartCollectionSection.swift
//  QuillStack
//
//  Created on 2026-01-09.
//

import SwiftUI
import CoreData

/// A collapsible section for displaying a smart collection
struct SmartCollectionSection: View {
    let collection: SmartCollection
    let noteCount: Int
    @Binding var isExpanded: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                onTap()
            }
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: collection.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.forestDark)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(Color.forestLight.opacity(0.2))
                    )

                // Title and count
                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.title)
                        .font(.serifBody(16, weight: .semibold))
                        .foregroundColor(.textDark)

                    if noteCount > 0 {
                        Text("\(noteCount) note\(noteCount == 1 ? "" : "s")")
                            .font(.serifCaption(13, weight: .regular))
                            .foregroundColor(.textMedium)
                    } else {
                        Text("No notes")
                            .font(.serifCaption(13, weight: .regular))
                            .foregroundColor(.textLight)
                    }
                }

                Spacer()

                // Chevron indicator
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.textMedium)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isExpanded)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isPressed ? Color.paperBeige.opacity(0.8) : Color.paperBeige
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.forestDark.opacity(0.1), lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.98 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

/// Container view for a smart collection with its notes
struct SmartCollectionContainer: View {
    let collection: SmartCollection
    let notes: [Note]
    @State private var isExpanded: Bool

    init(collection: SmartCollection, notes: [Note]) {
        self.collection = collection
        self.notes = notes
        self._isExpanded = State(initialValue: collection.defaultExpanded)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Section header
            SmartCollectionSection(
                collection: collection,
                noteCount: notes.count,
                isExpanded: $isExpanded,
                onTap: {
                    isExpanded.toggle()
                }
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)

            // Expanded notes list
            if isExpanded && !notes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(notes, id: \.objectID) { note in
                        NavigationLink(value: note) {
                            NoteCard(note: note)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 12)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
    }
}

#Preview {
    let collection = SmartCollection.recent
    SmartCollectionSection(
        collection: collection,
        noteCount: 5,
        isExpanded: .constant(false),
        onTap: {}
    )
    .padding()
    .background(Color.creamLight)
}
