//
//  ImageProcessor.swift
//  QuillStack
//
//  Created on 2025-12-10.
//

import UIKit
import CoreImage
import Vision

final class ImageProcessor {
    static let shared = ImageProcessor()

    private lazy var context: CIContext = {
        CIContext(options: [.useSoftwareRenderer: false])
    }()

    private init() {}

    /// Preloads expensive GPU resources on a background queue
    func warmUp() {
        _ = context
    }

    /// Preprocesses image for better OCR accuracy
    func preprocess(image: UIImage) -> UIImage? {
        guard let inputImage = CIImage(image: image) else { return nil }

        var processedImage = inputImage

        // 1. Auto-enhance
        let filters = processedImage.autoAdjustmentFilters()
        for filter in filters {
            filter.setValue(processedImage, forKey: kCIInputImageKey)
            if let outputImage = filter.outputImage {
                processedImage = outputImage
            }
        }

        // 2. Increase contrast for text clarity
        if let contrastFilter = CIFilter(name: "CIColorControls") {
            contrastFilter.setValue(processedImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(1.2, forKey: kCIInputContrastKey)
            if let output = contrastFilter.outputImage {
                processedImage = output
            }
        }

        // 3. Sharpen for text clarity
        if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
            sharpenFilter.setValue(processedImage, forKey: kCIInputImageKey)
            sharpenFilter.setValue(0.4, forKey: kCIInputSharpnessKey)
            if let output = sharpenFilter.outputImage {
                processedImage = output
            }
        }

        guard let cgImage = context.createCGImage(processedImage, from: processedImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    /// Corrects image orientation
    func correctOrientation(image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return normalizedImage ?? image
    }

    /// Generates a thumbnail from an image
    func generateThumbnail(from image: UIImage, maxSize: CGFloat = 200) -> UIImage? {
        let size = image.size
        let scale = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return thumbnail
    }

    /// Converts image to grayscale for better OCR
    func convertToGrayscale(image: UIImage) -> UIImage? {
        guard let inputImage = CIImage(image: image) else { return nil }

        let grayscaleFilter = CIFilter(name: "CIPhotoEffectMono")
        grayscaleFilter?.setValue(inputImage, forKey: kCIInputImageKey)

        guard let outputImage = grayscaleFilter?.outputImage,
              let cgImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }

    // MARK: - OCR-Optimized Processing

    /// Binarizes image (black/white) for cleaner text recognition
    func binarize(image: UIImage, threshold: Float = 0.5) -> UIImage? {
        guard let inputImage = CIImage(image: image) else { return nil }

        // Convert to grayscale first
        guard let monoFilter = CIFilter(name: "CIPhotoEffectMono") else { return nil }
        monoFilter.setValue(inputImage, forKey: kCIInputImageKey)
        guard let grayImage = monoFilter.outputImage else { return nil }

        // Apply threshold to create black/white image
        // CIColorThreshold is iOS 14+
        if #available(iOS 14.0, *) {
            guard let thresholdFilter = CIFilter(name: "CIColorThreshold") else { return nil }
            thresholdFilter.setValue(grayImage, forKey: kCIInputImageKey)
            thresholdFilter.setValue(threshold, forKey: "inputThreshold")

            guard let output = thresholdFilter.outputImage,
                  let cgImage = context.createCGImage(output, from: output.extent) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        } else {
            // Fallback: use high contrast instead
            guard let contrastFilter = CIFilter(name: "CIColorControls") else { return nil }
            contrastFilter.setValue(grayImage, forKey: kCIInputImageKey)
            contrastFilter.setValue(2.0, forKey: kCIInputContrastKey)

            guard let output = contrastFilter.outputImage,
                  let cgImage = context.createCGImage(output, from: output.extent) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        }
    }

    /// Detects and corrects document perspective/skew using Vision
    func deskew(image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        let request = VNDetectDocumentSegmentationRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let result = request.results?.first,
              let ciImage = CIImage(image: image) else { return nil }

        // Convert normalized coordinates to image coordinates
        let imageSize = ciImage.extent

        let topLeft = CGPoint(
            x: result.topLeft.x * imageSize.width,
            y: result.topLeft.y * imageSize.height
        )
        let topRight = CGPoint(
            x: result.topRight.x * imageSize.width,
            y: result.topRight.y * imageSize.height
        )
        let bottomLeft = CGPoint(
            x: result.bottomLeft.x * imageSize.width,
            y: result.bottomLeft.y * imageSize.height
        )
        let bottomRight = CGPoint(
            x: result.bottomRight.x * imageSize.width,
            y: result.bottomRight.y * imageSize.height
        )

        let corrected = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight)
        ])

        guard let outputCG = context.createCGImage(corrected, from: corrected.extent) else {
            return nil
        }
        return UIImage(cgImage: outputCG)
    }

    /// Scales image to optimal resolution for OCR (2000-4000px on long edge)
    func scaleForOCR(image: UIImage, targetMaxDimension: CGFloat = 3000) -> UIImage? {
        let currentMax = max(image.size.width, image.size.height)

        // Don't upscale small images too much, don't downscale if already optimal
        if currentMax >= 2000 && currentMax <= 4000 {
            return image
        }

        let scale: CGFloat
        if currentMax < 2000 {
            // Upscale small images to minimum optimal size
            scale = 2000 / currentMax
        } else {
            // Downscale very large images
            scale = targetMaxDimension / currentMax
        }

        let newSize = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let scaled = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return scaled
    }

    /// Complete preprocessing pipeline optimized for handwritten text OCR
    func preprocessForOCR(image: UIImage) -> UIImage? {
        var processed = image

        // 1. Correct orientation
        processed = correctOrientation(image: processed)

        // 2. Scale to optimal OCR resolution
        if let scaled = scaleForOCR(image: processed) {
            processed = scaled
        }

        // 3. Try to deskew document
        if let deskewed = deskew(image: processed) {
            processed = deskewed
        }

        // 4. Apply standard preprocessing (auto-adjust, contrast, sharpen)
        if let enhanced = preprocess(image: processed) {
            processed = enhanced
        }

        return processed
    }
}
