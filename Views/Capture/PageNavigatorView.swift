//
//  PageNavigatorView.swift
//  QuillStack
//
//  Created on 2025-12-18.
//

import SwiftUI
import CoreData

// MARK: - Page Navigator View

struct PageNavigatorView: View {
    @ObservedObject var note: Note
    @Environment(\.dismiss) private var dismiss

    @State private var currentPage = 0

    var pages: [NotePage] {
        note.sortedPages
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if pages.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 0) {
                        // Page content
                        pageContent

                        // Thumbnail strip
                        thumbnailStrip
                    }
                }
            }
            .navigationTitle("Page \(currentPage + 1) of \(pages.count)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.9), for: .navigationBar)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text.image")
                .font(.system(size: 48))
                .foregroundColor(.gray)

            Text("No pages available")
                .font(.serifBody(16, weight: .medium))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Page Content

    private var pageContent: some View {
        TabView(selection: $currentPage) {
            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                PageView(page: page)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    // MARK: - Thumbnail Strip

    private var thumbnailStrip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                        Button(action: {
                            withAnimation {
                                currentPage = index
                            }
                        }) {
                            ZStack(alignment: .bottomTrailing) {
                                if let thumbnail = page.thumbnail {
                                    Image(uiImage: thumbnail)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else if let image = page.image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 50, height: 70)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                } else {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 50, height: 70)
                                        .overlay(
                                            Text("\(index + 1)")
                                                .font(.serifCaption(14, weight: .bold))
                                                .foregroundColor(.white)
                                        )
                                }

                                // Page number badge
                                Text("\(index + 1)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(3)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                                    .offset(x: -2, y: -2)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(currentPage == index ? Color.forestLight : Color.clear, lineWidth: 2)
                            )
                        }
                        .id(index)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .background(Color.black.opacity(0.9))
            .onChange(of: currentPage) { _, newPage in
                withAnimation {
                    proxy.scrollTo(newPage, anchor: .center)
                }
            }
        }
    }
}

// MARK: - Page View

struct PageView: View {
    let page: NotePage
    @State private var showingText = false

    var body: some View {
        ZStack {
            // Page image
            if let image = page.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Image not available")
                        .font(.serifBody(14, weight: .medium))
                        .foregroundColor(.gray)
                }
            }

            // Text overlay toggle
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingText.toggle() }) {
                        Image(systemName: showingText ? "doc.text.fill" : "doc.text")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Circle())
                    }
                    .padding()
                }
            }
        }
        .sheet(isPresented: $showingText) {
            PageTextSheet(page: page)
        }
    }
}

// MARK: - Page Text Sheet

struct PageTextSheet: View {
    let page: NotePage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.creamLight.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Confidence indicator
                        HStack {
                            Text("OCR Confidence:")
                                .font(.serifCaption(13, weight: .medium))
                                .foregroundColor(.textMedium)

                            Text("\(Int(page.ocrConfidence * 100))%")
                                .font(.serifCaption(13, weight: .bold))
                                .foregroundColor(page.ocrConfidence > 0.8 ? .green : page.ocrConfidence > 0.6 ? .orange : .red)
                        }

                        Divider()

                        // OCR text
                        if let text = page.ocrText, !text.isEmpty {
                            Text(text)
                                .font(.serifBody(16, weight: .regular))
                                .foregroundColor(.textDark)
                                .lineSpacing(6)
                        } else {
                            Text("No text recognized on this page")
                                .font(.serifBody(14, weight: .regular))
                                .foregroundColor(.textMedium)
                                .italic()
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Page \(page.pageNumber + 1) Text")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.forestDark)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button(action: copyText) {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(.forestDark)
                    }
                }
            }
        }
    }

    private func copyText() {
        if let text = page.ocrText {
            UIPasteboard.general.string = text
        }
    }
}

// MARK: - Preview

#Preview {
    PageNavigatorView(note: Note())
}
