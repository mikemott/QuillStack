//
//  SimpleWelcomeView.swift
//  QuillStack
//
//  Created for QUI-150: API Key Onboarding Flow
//

import SwiftUI

struct SimpleWelcomeView: View {
    var onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                // App Icon or Logo Placeholder
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.forestDark, Color.forestMedium],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 100, height: 100)

                    Image(systemName: "doc.text.image")
                        .font(.system(size: 44, weight: .medium))
                        .foregroundColor(.forestLight)
                }
                .shadow(color: .forestDark.opacity(0.2), radius: 12, x: 0, y: 6)

                // Hero Message
                VStack(spacing: 16) {
                    Text("Transform Handwriting\nInto Action")
                        .font(.serifHeadline(32, weight: .bold))
                        .foregroundColor(.forestDark)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("Snap a photo. We'll figure out what to do with it.")
                        .font(.serifBody(17, weight: .regular))
                        .foregroundColor(.textMedium)
                        .multilineTextAlignment(.center)
                        .lineSpacing(6)
                }
                .padding(.horizontal, 32)

                // Three Examples
                VStack(spacing: 20) {
                    transformationExample(
                        from: "Business Card",
                        to: "Contact",
                        fromIcon: "person.text.rectangle",
                        toIcon: "person.crop.circle.fill",
                        color: .blue
                    )

                    transformationExample(
                        from: "Meeting Notes",
                        to: "Calendar Event",
                        fromIcon: "note.text",
                        toIcon: "calendar.badge.plus",
                        color: .purple
                    )

                    transformationExample(
                        from: "Todo List",
                        to: "Reminders",
                        fromIcon: "list.bullet",
                        toIcon: "checkmark.circle.fill",
                        color: .orange
                    )
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 16)

                // Privacy Message
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.forestDark)

                    Text("We Don't Want Your Data")
                        .font(.serifCaption(14, weight: .semibold))
                        .foregroundColor(.forestDark)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.forestDark.opacity(0.08))
                .cornerRadius(20)

                Spacer(minLength: 40)

                // Get Started Button
                Button(action: onContinue) {
                    Text("Get Started")
                        .font(.serifBody(18, weight: .semibold))
                        .foregroundColor(.forestLight)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            LinearGradient(
                                colors: [Color.forestDark, Color.forestMedium.opacity(0.9)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(14)
                        .shadow(color: .forestDark.opacity(0.2), radius: 6, x: 0, y: 3)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .background(Color.creamLight.ignoresSafeArea())
    }

    private func transformationExample(
        from: String,
        to: String,
        fromIcon: String,
        toIcon: String,
        color: Color
    ) -> some View {
        HStack(spacing: 16) {
            // From
            HStack(spacing: 10) {
                Image(systemName: fromIcon)
                    .font(.system(size: 18))
                    .foregroundColor(.textMedium)
                    .frame(width: 24)

                Text(from)
                    .font(.serifBody(15, weight: .medium))
                    .foregroundColor(.textDark)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Arrow
            Image(systemName: "arrow.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(color)

            // To
            HStack(spacing: 10) {
                Image(systemName: toIcon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 24)

                Text(to)
                    .font(.serifBody(15, weight: .semibold))
                    .foregroundColor(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

#Preview {
    SimpleWelcomeView(onContinue: {})
}
