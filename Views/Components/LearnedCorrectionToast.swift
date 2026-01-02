//
//  LearnedCorrectionToast.swift
//  QuillStack
//
//  Shows a brief celebratory toast when OCR corrections are learned.
//

import SwiftUI

struct LearnedCorrectionToast: View {
    let corrections: [(original: String, corrected: String)]
    @Binding var isShowing: Bool

    var body: some View {
        if isShowing {
            VStack(spacing: 0) {
                Spacer()

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 16))

                    if corrections.count == 1 {
                        Text("Learned: \(corrections[0].original) → \(corrections[0].corrected)")
                            .font(.serifBody(14, weight: .medium))
                            .foregroundColor(.textDark)
                    } else {
                        Text("Learned \(corrections.count) corrections")
                            .font(.serifBody(14, weight: .medium))
                            .foregroundColor(.textDark)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.forestDark.opacity(0.95))
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                )
                .foregroundColor(.white)
                .padding(.bottom, 20)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.3), value: isShowing)
            .onAppear {
                // Auto-dismiss after 2.5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    withAnimation {
                        isShowing = false
                    }
                }
            }
        }
    }
}

#Preview {
    ZStack {
        Color.creamLight.ignoresSafeArea()

        LearnedCorrectionToast(
            corrections: [("narn", "name"), ("ernail", "email")],
            isShowing: .constant(true)
        )
    }
}
