//
//  SmallWidgetView.swift
//  QuillStackWidget
//
//  Created on 2026-01-02.
//

import SwiftUI
import WidgetKit

struct SmallWidgetView: View {
    let entry: NotesEntry

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "F5F1E8"), Color(hex: "E8DCC8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                // Capture buttons
                HStack(spacing: 10) {
                    // Voice button
                    Link(destination: URL(string: "quillstack://capture/voice")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "mic.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "2D5F4F"), Color(hex: "1E4335")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("Voice")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "1E4335"))
                        }
                    }

                    // Scan button
                    Link(destination: URL(string: "quillstack://capture/camera")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "2D5F4F"), Color(hex: "1E4335")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Text("Scan")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Color(hex: "1E4335"))
                        }
                    }
                }

                // Note count
                HStack(spacing: 4) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 12))
                    Text("\(entry.todayStats.totalNotes) notes today")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(Color(hex: "1E4335").opacity(0.7))
            }
            .padding()
        }
    }
}

// Color extension for hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
