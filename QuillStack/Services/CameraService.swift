import AVFoundation
import UIKit
import Vision

@MainActor
@Observable
final class CameraService {
    private(set) var isSessionRunning = false
    private(set) var capturedImage: UIImage?

    private let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "camera.session")
    private var delegate: PhotoCaptureDelegate?

    var previewSession: AVCaptureSession { session }

    func configure() {
        sessionQueue.async { [self] in
            session.beginConfiguration()
            session.sessionPreset = .photo

            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else {
                session.commitConfiguration()
                return
            }

            session.addInput(input)

            guard session.canAddOutput(photoOutput) else {
                session.commitConfiguration()
                return
            }
            session.addOutput(photoOutput)
            photoOutput.isHighResolutionCaptureEnabled = true
            session.commitConfiguration()
        }
    }

    func start() {
        sessionQueue.async { [self] in
            guard !session.isRunning else { return }
            session.startRunning()
            Task { @MainActor in isSessionRunning = true }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
            Task { @MainActor in isSessionRunning = false }
        }
    }

    func capture() async -> UIImage? {
        await withCheckedContinuation { continuation in
            let settings = AVCapturePhotoSettings()
            let delegate = PhotoCaptureDelegate { [weak self] image in
                Task { @MainActor in
                    self?.capturedImage = image
                }
                continuation.resume(returning: image)
            }
            self.delegate = delegate
            photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }

    func clearCapture() {
        capturedImage = nil
    }
}

// MARK: - Document Detection

extension CameraService {
    static func detectAndCorrectDocument(in image: UIImage) async -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        return await withCheckedContinuation { continuation in
            let request = VNDetectDocumentSegmentationRequest { request, _ in
                guard let result = request.results?.first as? VNRectangleObservation else {
                    continuation.resume(returning: image)
                    return
                }
                let corrected = perspectiveCorrect(cgImage: cgImage, observation: result)
                continuation.resume(returning: corrected ?? image)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage)
            try? handler.perform([request])
        }
    }

    private static func perspectiveCorrect(cgImage: CGImage, observation: VNRectangleObservation) -> UIImage? {
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        func convert(_ point: CGPoint) -> CGPoint {
            CGPoint(x: point.x * imageSize.width, y: (1 - point.y) * imageSize.height)
        }

        let topLeft = convert(observation.topLeft)
        let topRight = convert(observation.topRight)
        let bottomLeft = convert(observation.bottomLeft)
        let bottomRight = convert(observation.bottomRight)

        let ciImage = CIImage(cgImage: cgImage)
        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else { return nil }
        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: topLeft), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: topRight), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bottomLeft), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: bottomRight), forKey: "inputBottomRight")

        guard let output = filter.outputImage else { return nil }
        let context = CIContext()
        guard let correctedCG = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: correctedCG)
    }
}

// MARK: - Photo Capture Delegate

private final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    private let completion: (UIImage?) -> Void

    init(completion: @escaping (UIImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            completion(nil)
            return
        }
        completion(image)
    }
}
