import MLXLMCommon
import MLXVLM
import MLX
import CoreImage
import os

@MainActor
@Observable
final class VLMStatus {
    static let shared = VLMStatus()
    var state: VLMLoadState = .idle

    enum VLMLoadState: Equatable {
        case idle
        case downloading(progress: Double)
        case loading
        case ready
        case failed(String)
    }
}

actor VLMService {
    static let shared = VLMService()

    private var modelContainer: ModelContainer?
    private var isLoading = false

    private static let logger = Logger(subsystem: "com.quillstack", category: "VLMService")
    private static let modelID = "mlx-community/Qwen2-VL-2B-Instruct-4bit"

    var isReady: Bool { modelContainer != nil }

    func loadModel() async throws {
        guard modelContainer == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        Self.logger.info("Loading VLM model: \(Self.modelID)")
        Memory.cacheLimit = 20 * 1024 * 1024

        await MainActor.run { VLMStatus.shared.state = .downloading(progress: 0) }

        let container = try await loadModelContainer(id: Self.modelID) { progress in
            Task { @MainActor in
                VLMStatus.shared.state = .downloading(progress: progress.fractionCompleted)
            }
        }

        await MainActor.run { VLMStatus.shared.state = .loading }

        modelContainer = container

        await MainActor.run { VLMStatus.shared.state = .ready }
        Self.logger.info("VLM model loaded")
    }

    func describeImage(_ imageData: Data) async throws -> String {
        guard let container = modelContainer else {
            throw VLMError.modelNotLoaded
        }

        guard let ciImage = CIImage(data: imageData) else {
            throw VLMError.invalidImage
        }

        let session = ChatSession(
            container,
            generateParameters: GenerateParameters(temperature: 0.0),
            processing: UserInput.Processing(resize: CGSize(width: 1024, height: 1024))
        )

        let prompt = """
        Read this image carefully. List everything you see:
        1. All visible text, transcribed exactly
        2. What type of document or item this is
        3. Any names, dates, phone numbers, emails, URLs, or addresses
        """

        let response = try await session.respond(to: prompt, image: .ciImage(ciImage))
        Self.logger.debug("VLM description: \(response)")
        return response
    }
}

enum VLMError: Error, LocalizedError {
    case modelNotLoaded
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .modelNotLoaded: "VLM model is not loaded"
        case .invalidImage: "Could not create image from data"
        }
    }
}
