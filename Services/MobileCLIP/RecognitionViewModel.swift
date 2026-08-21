import Combine
import Foundation
import UIKit

@MainActor
final class RecognitionViewModel: ObservableObject {
    static let shared = RecognitionViewModel()

    @Published private(set) var recognitionState: RecognitionState = .idle
    @Published private(set) var processingTime: Double = 0

    private let scanService: SemanticRecognitionScanService

    init(scanService: SemanticRecognitionScanService = SemanticRecognitionScanService()) {
        self.scanService = scanService
    }

    func recognizeObject(in image: UIImage) {
        let startTime = Date()
        recognitionState = .processing

        Task { [scanService] in
            do {
                let results = try await scanService.recognizeObject(in: image)
                let elapsed = Date().timeIntervalSince(startTime)
                processingTime = elapsed
                guard let first = results.first else {
                    recognitionState = .error("未检测到物体")
                    return
                }
                recognitionState = .success(first)
            } catch {
                processingTime = Date().timeIntervalSince(startTime)
                recognitionState = .error(error.localizedDescription)
            }
        }
    }

    func reset() {
        recognitionState = .idle
        processingTime = 0
    }
}
