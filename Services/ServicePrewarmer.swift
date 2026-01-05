import Foundation

enum ServicePrewarmer {
    private static var hasStartedWarmup = false

    static func warmHeavyServices() {
        guard !hasStartedWarmup else { return }
        hasStartedWarmup = true

        Task.detached(priority: .utility) {
            // Force expensive GPU contexts and OCR singletons to initialize off the main thread
            ImageProcessor.shared.warmUp()
            _ = OCRService.shared
        }
    }
}
