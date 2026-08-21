import CoreGraphics
import Foundation

enum RecognitionSource: String, Codable, Equatable {
    case yolo
    case mobileCLIP
}

struct RecognitionResult: Identifiable, Equatable {
    let id: UUID
    let objectName: String
    let confidence: Float
    let description: String
    let timestamp: Date
    let alternativeMatches: [String: Float]
    let detectionBox: CGRect
    let source: RecognitionSource

    init(
        id: UUID = UUID(),
        objectName: String,
        confidence: Float,
        description: String,
        timestamp: Date = Date(),
        alternativeMatches: [String: Float] = [:],
        detectionBox: CGRect,
        source: RecognitionSource = .yolo
    ) {
        self.id = id
        self.objectName = objectName
        self.confidence = min(max(confidence, 0), 1)
        self.description = description
        self.timestamp = timestamp
        self.alternativeMatches = alternativeMatches
        self.detectionBox = detectionBox
        self.source = source
    }

    var confidencePercentage: Int {
        Int((confidence * 100).rounded())
    }

    var confidenceLevel: String {
        switch confidence {
        case 0.85...: "非常高"
        case 0.70...: "很高"
        case 0.50...: "中等"
        default: "较低"
        }
    }
}

struct DetectionBox: Equatable {
    let x: Float
    let y: Float
    let width: Float
    let height: Float
    let confidence: Float

    init(x: Float, y: Float, width: Float, height: Float, confidence: Float) {
        self.x = min(max(x, 0), 1)
        self.y = min(max(y, 0), 1)
        self.width = min(max(width, 0), 1)
        self.height = min(max(height, 0), 1)
        self.confidence = min(max(confidence, 0), 1)
    }

    func toCGRect(imageSize: CGSize) -> CGRect {
        let normalized = CGRect(
            x: CGFloat(x - width / 2),
            y: CGFloat(y - height / 2),
            width: CGFloat(width),
            height: CGFloat(height)
        ).intersection(CGRect(x: 0, y: 0, width: 1, height: 1))
        return CGRect(
            x: normalized.minX * imageSize.width,
            y: normalized.minY * imageSize.height,
            width: normalized.width * imageSize.width,
            height: normalized.height * imageSize.height
        )
    }
}

enum RecognitionState: Equatable {
    case idle
    case processing
    case success(RecognitionResult)
    case error(String)
}

extension RecognitionResult {
    init(item: DetectedItem, imageSize: CGSize, alternatives: [(String, Float)] = [], source: RecognitionSource = .yolo) {
        let box = item.arHint.map {
            DetectionBox(
                x: Float($0.x),
                y: Float($0.y),
                width: Float($0.width),
                height: Float($0.height),
                confidence: Float(item.confidence)
            ).toCGRect(imageSize: imageSize)
        } ?? .zero
        let alternativeMatches = alternatives.reduce(into: [String: Float]()) { result, match in
            result[match.0] = match.1
        }
        self.init(
            objectName: item.name,
            confidence: Float(item.confidence),
            description: "检测到\(item.name)，置信度 \(Int((item.confidence * 100).rounded()))%",
            alternativeMatches: alternativeMatches,
            detectionBox: box,
            source: source
        )
    }
}
