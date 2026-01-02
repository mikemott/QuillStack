//
//  PageHeader.swift
//  QuillStack
//
//  Created on 2026-01-02.
//

import SwiftUI

/// Reusable page header with dark green gradient background
/// Matches the NoteListView header styling for consistency across tabs
struct PageHeader<TrailingContent: View>: View {
    let title: String
    var trailingContent: (() -> TrailingContent)?

    init(title: String, @ViewBuilder trailingContent: @escaping () -> TrailingContent) {
        self.title = title
        self.trailingContent = trailingContent
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Dark green gradient background
            LinearGradient(
                colors: [Color.forestMedium, Color.forestDark],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .top)

            HStack(alignment: .center) {
                Text(title)
                    .font(.serifTitle(28, weight: .bold))
                    .foregroundColor(.forestLight)

                Spacer()

                if let trailingContent = trailingContent {
                    trailingContent()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 110)
    }
}

// Extension for headers without trailing content
extension PageHeader where TrailingContent == EmptyView {
    init(title: String) {
        self.title = title
        self.trailingContent = nil
    }
}

#Preview {
    VStack(spacing: 0) {
        PageHeader(title: "Settings")
        Spacer()
    }
    .background(Color.creamLight)
}
