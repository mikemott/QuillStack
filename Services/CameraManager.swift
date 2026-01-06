//
//  CameraManager.swift
//  QuillStack
//
//  Created on 2025-12-10.
//  Updated for iOS 26 / Swift 6.2 concurrency patterns
//

import AVFoundation
import UIKit
import os.log

@MainActor
@Observable
final class CameraManager: NSObject {
    // Logger must be nonisolated to be accessible from delegate callbacks
    nonisolated(unsafe) private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "QuillStack", category: "Camera")
    // Observable state (main actor)
    var isAuthorized = false
    var isCameraUnavailable = false
    var capturedImage: UIImage?
    var error: CameraError?
    var isSessionRunning = false
    var flashMode: AVCaptureDevice.FlashMode = .auto

    // AVFoundation objects - must be accessed from sessionQueue
    // Using nonisolated(unsafe) because AVCaptureSession requires background queue access
    nonisolated(unsafe) private let session = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    @ObservationIgnored private var _currentCameraPosition: AVCaptureDevice.Position = .back

    private let sessionQueue = DispatchQueue(label: "camera.session.queue")

    enum CameraError: LocalizedError, Sendable {
        case cameraUnavailable
        case cannotAddInput
        case cannotAddOutput
        case captureSessionError

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return "Camera is not available on this device"
            case .cannotAddInput:
                return "Cannot access camera input"
            case .cannotAddOutput:
                return "Cannot configure camera output"
            case .captureSessionError:
                return "Camera session error occurred"
            }
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupAndStartSession()

        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    self.isAuthorized = granted
                    if granted {
                        self.setupAndStartSession()
                    }
                }
            }

        case .denied, .restricted:
            isAuthorized = false

        @unknown default:
            isAuthorized = false
        }
    }

    // MARK: - Camera Setup

    private func setupAndStartSession() {
        let position = _currentCameraPosition
        sessionQueue.async { [self] in
            configureSessionOnQueue(cameraPosition: position)
        }
    }

    private nonisolated func configureSessionOnQueue(cameraPosition: AVCaptureDevice.Position) {
        // Stop session if running (for reconfiguration)
        if session.isRunning {
            session.stopRunning()
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        // Remove existing inputs
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        // Configure input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                    for: .video,
                                                    position: cameraPosition) else {
            Task { @MainActor in
                self.isCameraUnavailable = true
            }
            session.commitConfiguration()
            return
        }

        do {
            let cameraInput = try AVCaptureDeviceInput(device: camera)

            if session.canAddInput(cameraInput) {
                session.addInput(cameraInput)
            } else {
                Task { @MainActor in
                    self.error = .cannotAddInput
                }
                session.commitConfiguration()
                return
            }

            // Configure photo output
            if session.canAddOutput(photoOutput) {
                session.addOutput(photoOutput)

                // Use maxPhotoDimensions for high resolution capture
                if let maxDimensions = camera.activeFormat.supportedMaxPhotoDimensions.max(by: { $0.width * $0.height < $1.width * $1.height }) {
                    photoOutput.maxPhotoDimensions = maxDimensions
                }
                photoOutput.maxPhotoQualityPrioritization = .quality
            } else {
                Task { @MainActor in
                    self.error = .cannotAddOutput
                }
                session.commitConfiguration()
                return
            }

        } catch {
            Task { @MainActor in
                self.error = .cannotAddInput
            }
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()

        // Start the session
        session.startRunning()
        let isRunning = session.isRunning
        Task { @MainActor in
            self.isSessionRunning = isRunning
        }
    }

    // MARK: - Session Control

    nonisolated func startSession() {
        sessionQueue.async { [self] in
            if !session.isRunning {
                session.startRunning()
                let isRunning = session.isRunning
                Task { @MainActor in
                    self.isSessionRunning = isRunning
                }
            }
        }
    }

    nonisolated func stopSession() {
        sessionQueue.async { [self] in
            if session.isRunning {
                session.stopRunning()
                Task { @MainActor in
                    self.isSessionRunning = false
                }
            }
        }
    }

    // MARK: - Photo Capture

    func capturePhoto() {
        let currentFlashMode = flashMode
        sessionQueue.async { [self] in
            guard session.isRunning else {
                Task { @MainActor in
                    self.error = .captureSessionError
                }
                return
            }

            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality

            // Apply user's flash mode if supported, otherwise fall back gracefully
            if photoOutput.supportedFlashModes.contains(currentFlashMode) {
                settings.flashMode = currentFlashMode
            } else if photoOutput.supportedFlashModes.contains(.auto) {
                settings.flashMode = .auto
            }

            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    // MARK: - Camera Position

    func switchCamera() {
        _currentCameraPosition = _currentCameraPosition == .back ? .front : .back
        let position = _currentCameraPosition

        sessionQueue.async { [self] in
            // Stop and reconfigure
            session.stopRunning()
            Task { @MainActor in
                self.isSessionRunning = false
            }

            // Reconfigure with new camera position
            configureSessionOnQueue(cameraPosition: position)
        }
    }

    // MARK: - Flash Control

    func toggleFlash() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on: flashMode = .off
        case .off: flashMode = .auto
        @unknown default: flashMode = .auto
        }
    }

    // MARK: - Preview Layer

    nonisolated func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        return previewLayer
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraManager: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            Task { @MainActor in
                self.error = .captureSessionError
            }
            Self.logger.error("Photo capture error: \(error.localizedDescription)")
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Task { @MainActor in
                self.error = .captureSessionError
            }
            return
        }

        // Fix orientation
        let fixedImage = image.fixOrientationSync()

        Task { @MainActor in
            self.capturedImage = fixedImage
        }
    }
}

// MARK: - UIImage Orientation Fix

extension UIImage {
    nonisolated func fixOrientationSync() -> UIImage {
        if imageOrientation == .up {
            return self
        }

        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        draw(in: CGRect(origin: .zero, size: size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? self
    }
}
