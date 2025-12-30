//
//  OnboardingCalendarPage.swift
//  QuillStack
//
//  Created on 2025-12-30.
//

import SwiftUI
import EventKit

struct OnboardingCalendarPage: View {
    var onContinue: () -> Void
    var onSkip: () -> Void

    @State private var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @State private var isRequesting = false

    private let eventStore = EKEventStore()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.red.opacity(0.1))
                        .frame(width: 80, height: 80)

                    Image(systemName: "calendar")
                        .font(.system(size: 36, weight: .medium))
                        .foregroundColor(.red)
                }

                Text("Calendar Integration")
                    .font(.serifHeadline(26, weight: .bold))
                    .foregroundColor(.forestDark)

                Text("Create calendar events from\nmeeting notes automatically")
                    .font(.serifBody(15, weight: .regular))
                    .foregroundColor(.textMedium)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            // Status card
            statusCard
                .padding(.horizontal, 24)

            // How it works
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.forestDark)
                    Text("How it works")
                        .font(.serifBody(14, weight: .semibold))
                        .foregroundColor(.forestDark)
                }

                VStack(alignment: .leading, spacing: 10) {
                    tipRow("1", "Write #meeting# on paper with date/time")
                    tipRow("2", "Capture and QuillStack extracts details")
                    tipRow("3", "One tap to add to your calendar")
                }
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(14)
            .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
            .padding(.horizontal, 24)

            Spacer()

            // Continue button (if authorized)
            if authorizationStatus == .fullAccess || authorizationStatus == .writeOnly {
                Button(action: onContinue) {
                    Text("Continue")
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
                }
                .padding(.horizontal, 32)
            }

            // Skip button
            Button(action: onSkip) {
                Text("Skip for now")
                    .font(.serifBody(15, weight: .medium))
                    .foregroundColor(.textMedium)
            }
            .padding(.bottom, 20)
        }
        .onAppear {
            checkAuthorizationStatus()
        }
    }

    // MARK: - Status Card

    @ViewBuilder
    private var statusCard: some View {
        VStack(spacing: 16) {
            switch authorizationStatus {
            case .notDetermined:
                notDeterminedView

            case .fullAccess, .writeOnly:
                authorizedView

            case .denied, .restricted:
                deniedView

            @unknown default:
                notDeterminedView
            }
        }
        .padding(20)
        .background(Color.white)
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 3)
    }

    private var notDeterminedView: some View {
        VStack(spacing: 16) {
            Text("QuillStack needs calendar access to create events from your meeting notes.")
                .font(.serifBody(14, weight: .regular))
                .foregroundColor(.textMedium)
                .multilineTextAlignment(.center)

            Button(action: requestAccess) {
                HStack(spacing: 10) {
                    if isRequesting {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    }
                    Text(isRequesting ? "Requesting..." : "Allow Calendar Access")
                        .font(.serifBody(16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.red)
                .cornerRadius(10)
            }
            .disabled(isRequesting)
        }
    }

    private var authorizedView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("Calendar Access Granted")
                    .font(.serifBody(16, weight: .semibold))
                    .foregroundColor(.textDark)

                Text("You can create events from meeting notes")
                    .font(.serifCaption(13, weight: .regular))
                    .foregroundColor(.textMedium)
            }

            Spacer()
        }
    }

    private var deniedView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Access Denied")
                        .font(.serifBody(15, weight: .semibold))
                        .foregroundColor(.textDark)

                    Text("Enable in Settings → Privacy → Calendars")
                        .font(.serifCaption(12, weight: .regular))
                        .foregroundColor(.textMedium)
                }

                Spacer()
            }

            Button(action: openSettings) {
                Text("Open Settings")
                    .font(.serifBody(14, weight: .semibold))
                    .foregroundColor(.forestDark)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.forestDark.opacity(0.1))
                    .cornerRadius(8)
            }
        }
    }

    private func tipRow(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.forestDark.opacity(0.7))
                .clipShape(Circle())

            Text(text)
                .font(.serifCaption(13, weight: .regular))
                .foregroundColor(.textMedium)
        }
    }

    // MARK: - Actions

    private func checkAuthorizationStatus() {
        authorizationStatus = EKEventStore.authorizationStatus(for: .event)
    }

    private func requestAccess() {
        isRequesting = true

        Task {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run {
                    isRequesting = false
                    checkAuthorizationStatus()

                    if granted {
                        // Auto-continue after brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            onContinue()
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    isRequesting = false
                    checkAuthorizationStatus()
                }
            }
        }
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    OnboardingCalendarPage(onContinue: {}, onSkip: {})
}
