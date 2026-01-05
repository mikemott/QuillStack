//
//  VoiceMemoViewModel.swift
//  QuillStack
//
//  Created for QUI-102 to power voice memo capture and transcription.
//

import Foundation
import AVFoundation
import Speech
import CoreData
import Combine

@MainActor
@Observable
final class VoiceMemoViewModel {
    enum SaveState: Equatable {
        case idle
        case saving
        case success(Int)
        case failure(String)
    }

    var transcript: String = "" {
        didSet {
            if oldValue != transcript {
                updateDetectedSections()
                if saveState != .idle {
                    saveState = .idle
                }
            }
        }
    }

    private(set) var detectedSections: [NoteSection] = []
    private(set) var isRecording = false
    private(set) var isSaving = false
    var saveState: SaveState = .idle
    var errorMessage: String?
    private(set) var microphoneGranted = false
    private(set) var speechGranted = false

    // Audio engine resources marked as nonisolated(unsafe) for deinit cleanup.
    // This is safe because:
    // 1. These are only accessed in deinit (cleanup only, no race conditions)
    // 2. AVAudioEngine operations used here are thread-safe
    // 3. No concurrent modification occurs - deinit is the final access
    nonisolated(unsafe) private let audioEngine = AVAudioEngine()
    nonisolated(unsafe) private var audioTapInstalled = false
    nonisolated(unsafe) private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    nonisolated(unsafe) private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?
    private let textClassifier: TextClassifierProtocol
    private var manualPrefix: String = ""

    init(
        locale: Locale = Locale.autoupdatingCurrent,
        textClassifier: TextClassifierProtocol? = nil
    ) {
        self.speechRecognizer = SFSpeechRecognizer(locale: locale)
        self.textClassifier = textClassifier ?? TextClassifier()
        self.microphoneGranted = AVAudioSession.sharedInstance().recordPermission == .granted

        let currentSpeechStatus = SFSpeechRecognizer.authorizationStatus()
        self.speechGranted = currentSpeechStatus == .authorized
    }

    deinit {
        // Cleanup audio resources on deallocation
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        if audioTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Permissions

    func requestPermissions() async {
        if AVAudioSession.sharedInstance().recordPermission == .undetermined {
            microphoneGranted = await requestMicrophoneAuthorization()
        } else {
            microphoneGranted = AVAudioSession.sharedInstance().recordPermission == .granted
        }

        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        if currentStatus == .notDetermined {
            let newStatus = await requestSpeechAuthorization()
            speechGranted = newStatus == .authorized
        } else {
            speechGranted = currentStatus == .authorized
        }

        if !microphoneGranted {
            errorMessage = "Enable microphone access in Settings to record voice memos."
        } else if !speechGranted {
            errorMessage = "Enable speech recognition in Settings to transcribe voice memos."
        }
    }

    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - Recording

    func startRecording() {
        guard !isRecording else { return }
        guard microphoneGranted else {
            errorMessage = "Microphone access is required to capture voice memos."
            return
        }
        guard speechGranted else {
            errorMessage = "Speech recognition access is required to transcribe voice memos."
            return
        }
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognition is currently unavailable on this device."
            return
        }

        manualPrefix = transcript

        recognitionTask?.cancel()
        recognitionTask = nil
        errorMessage = nil

        do {
            try configureAudioSession()

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            if audioTapInstalled {
                inputNode.removeTap(onBus: 0)
                audioTapInstalled = false
            }
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            // Install audio tap with larger buffer for better speech capture
            // Using 4096 samples for more reliable streaming
            inputNode.installTap(onBus: 0, bufferSize: 4096, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            audioTapInstalled = true

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let result = result {
                    Task { @MainActor in
                        let recognized = result.bestTranscription.formattedString
                        if self.manualPrefix.isEmpty {
                            self.transcript = recognized
                        } else {
                            let separator = self.manualPrefix.hasSuffix("\n") ? "" : "\n\n"
                            self.transcript = self.manualPrefix + separator + recognized
                        }
                        if result.isFinal {
                            self.finishRecordingSession(cancelTask: false)
                        }
                    }
                }

                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Transcription failed: \(error.localizedDescription)"
                        self.finishRecordingSession(cancelTask: true)
                    }
                }
            }

            audioEngine.prepare()
            try audioEngine.start()
            isRecording = true
        } catch {
            errorMessage = "Unable to start recording: \(error.localizedDescription)"
            finishRecordingSession(cancelTask: true)
        }
    }

    func stopRecording() {
        finishRecordingSession(cancelTask: false)
    }

    func resetTranscript() {
        transcript = ""
        saveState = .idle
        errorMessage = nil
        manualPrefix = ""
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers, .allowBluetooth])
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func finishRecordingSession(cancelTask: Bool) {
        if audioEngine.isRunning {
            audioEngine.stop()
        }

        if audioTapInstalled {
            audioEngine.inputNode.removeTap(onBus: 0)
            audioTapInstalled = false
        }

        recognitionRequest?.endAudio()
        if cancelTask {
            recognitionTask?.cancel()
        }

        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        manualPrefix = ""

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Saving

    var canSave: Bool {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isRecording && !isSaving
    }

    var permissionWarningMessage: String? {
        if !microphoneGranted {
            return "Microphone access is disabled. Enable it in Settings > Privacy > Microphone."
        }
        if !speechGranted {
            return "Speech recognition access is disabled. Enable it in Settings > Privacy > Speech Recognition."
        }
        if let speechRecognizer, !speechRecognizer.isAvailable {
            return "Speech recognition is temporarily unavailable. Try again in a moment."
        }
        return nil
    }

    var canStartRecording: Bool {
        permissionWarningMessage == nil
    }

    func saveTranscript() async {
        guard canSave else {
            if isRecording {
                errorMessage = "Stop recording before saving."
            } else {
                errorMessage = "Record or type something before saving."
            }
            return
        }

        isSaving = true
        saveState = .saving
        errorMessage = nil

        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let sections = textClassifier.splitIntoSections(content: trimmed)
        let sanitizedSections = sections
            .map { (type: $0.noteType, content: $0.content.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { !$0.content.isEmpty }

        guard !sanitizedSections.isEmpty else {
            saveState = .failure("Nothing to save.")
            isSaving = false
            return
        }

        var savedCount = 0

        for section in sanitizedSections {
            if await saveNote(text: section.content, noteType: section.type) != nil {
                savedCount += 1
            }
        }

        if savedCount > 0 {
            saveState = .success(savedCount)
            transcript = ""
            manualPrefix = ""
        } else {
            saveState = .failure("Failed to save voice memo.")
        }

        isSaving = false
    }

    private func saveNote(text: String, noteType: NoteType) async -> UUID? {
        let context = CoreDataStack.shared.newBackgroundContext()

        return await context.perform {
            let note = Note.create(
                in: context,
                content: text,
                noteType: noteType.rawValue
            )

            note.ocrConfidence = 1.0
            note.updatedAt = Date()

            switch noteType {
            case .todo:
                let parser = TodoParser(context: context)
                _ = parser.parseTodos(from: text, note: note)
            case .meeting:
                let parser = MeetingParser(context: context)
                _ = parser.parseMeeting(from: text, note: note)
            case .contact:
                _ = ContactParser.parse(text)
            case .email, .general, .claudePrompt, .reminder, .expense, .shopping, .recipe, .event, .idea:
                break
            }

            do {
                try CoreDataStack.shared.save(context: context)
                NotificationCenter.default.post(name: AppConstants.Notifications.noteCreated, object: nil)
                return note.id
            } catch {
                Task { @MainActor in
                    self.errorMessage = "Failed to save note: \(error.localizedDescription)"
                }
                return nil
            }
        }
    }

    // MARK: - Detected Sections

    private func updateDetectedSections() {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            detectedSections = []
            return
        }

        detectedSections = textClassifier.splitIntoSections(content: trimmed)
    }
}
