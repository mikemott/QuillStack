//
//  Constants.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import Foundation
import SwiftUI

enum AppConstants {
    // MARK: - App Info
    static let appName = "Quill Stack"
    static let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    static let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    // MARK: - OCR Settings
    enum OCR {
        static let minimumConfidence: Float = 0.5
        static let recognitionLanguage = "en-US"
        static let defaultRecognitionLevel = "accurate" // or "fast"
        static let maxImageSize: CGFloat = 4096
    }

    // MARK: - Image Processing
    enum Image {
        static let thumbnailSize: CGFloat = 200
        static let compressionQuality: CGFloat = 0.8
        static let maxStorageSize: Int = 5_000_000 // 5MB max per image
    }

    // MARK: - UI Settings
    enum UI {
        static let cornerRadius: CGFloat = 12
        static let standardPadding: CGFloat = 16
        static let cardShadowRadius: CGFloat = 4
        static let minimumTouchTarget: CGFloat = 44

        // Animation durations
        static let shortAnimationDuration: Double = 0.2
        static let standardAnimationDuration: Double = 0.3
        static let longAnimationDuration: Double = 0.5
    }

    // MARK: - Data Management
    enum Data {
        static let coreDataModelName = "QuillStack"
        static let maxRecentNotes = 100
        static let pageSize = 20 // For pagination
    }

    // MARK: - Notifications
    enum Notifications {
        static let noteCreated = Notification.Name("noteCreated")
        static let noteUpdated = Notification.Name("noteUpdated")
        static let noteDeleted = Notification.Name("noteDeleted")
        static let todoStatusChanged = Notification.Name("todoStatusChanged")
    }

    // MARK: - UserDefaults Keys
    enum UserDefaultsKeys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let preferredOCRLevel = "preferredOCRLevel"
        static let autoClassifyNotes = "autoClassifyNotes"
        static let showConfidenceScores = "showConfidenceScores"
    }

    // MARK: - Accessibility
    enum Accessibility {
        static let captureButtonLabel = "Capture note"
        static let captureButtonHint = "Takes a photo of your handwritten note"
        static let deleteNoteLabel = "Delete note"
        static let editNoteLabel = "Edit note"
        static let markTaskCompleteLabel = "Mark task as complete"
    }

    // MARK: - Error Messages
    enum ErrorMessages {
        static let cameraUnavailable = "Camera is not available on this device"
        static let cameraPermissionDenied = "Camera permission denied. Please enable in Settings."
        static let ocrFailed = "Failed to recognize text from image"
        static let saveFailed = "Failed to save note"
        static let loadFailed = "Failed to load notes"
        static let networkUnavailable = "No network connection"
        static let unknownError = "An unknown error occurred"
    }

    // MARK: - Feature Flags
    enum FeatureFlags {
        static let enableMeetingDetection = true
        static let enableTodoDetection = true
        static let enableCalendarIntegration = false // Phase 2
        static let enableLLMIntegration = false // Phase 2+
    }
}

// MARK: - App Configuration

struct AppConfiguration {
    static var isDebug: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    static var deviceModel: String {
        UIDevice.current.model
    }

    static var systemVersion: String {
        UIDevice.current.systemVersion
    }
}
