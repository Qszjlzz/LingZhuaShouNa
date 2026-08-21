import Accelerate
import CoreML
import Foundation

enum MobileCLIPTextError: LocalizedError {
    case textEncoderMissing
    case tokenizerResourcesMissing
    case invalidEmbedding

    var errorDescription: String? {
        switch self {
        case .textEncoderMissing: "未找到 MobileCLIP 文本编码器。"
        case .tokenizerResourcesMissing: "未找到 CLIP tokenizer 资源。"
        case .invalidEmbedding: "MobileCLIP 文本编码器未返回有效的 512 维特征。"
        }
    }
}

/// Adapter for the official MobileCLIP text model. It deliberately uses the
/// tokenizer shipped with Apple's sample instead of hashing category names.
final class MobileCLIPTextFeatureExtractor: @unchecked Sendable {
    static let shared = MobileCLIPTextFeatureExtractor()

    private let model: MLModel?
    private let tokenizer: CLIPTokenizer?

    private init(bundle: Bundle = .main) {
        let modelURL = [
            bundle.url(forResource: "mobileclip_s0_text", withExtension: "mlmodelc"),
            bundle.url(forResource: "mobileclip_s1_text", withExtension: "mlmodelc"),
            bundle.url(forResource: "MobileCLIPTextEncoder", withExtension: "mlmodelc"),
            bundle.url(forResource: "mobileclip_text_encoder", withExtension: "mlmodelc")
        ]
        .compactMap { $0 }
        .first

        if let modelURL {
            let configuration = MLModelConfiguration()
            #if targetEnvironment(simulator)
            configuration.computeUnits = .cpuOnly
            #else
            configuration.computeUnits = .all
            #endif
            model = try? MLModel(contentsOf: modelURL, configuration: configuration)
        } else {
            model = nil
        }

        if bundle.url(forResource: "clip-vocab", withExtension: "json") != nil,
           bundle.url(forResource: "clip-merges", withExtension: "txt") != nil {
            tokenizer = CLIPTokenizer()
        } else {
            tokenizer = nil
        }
    }

    var isAvailable: Bool { model != nil && tokenizer != nil }

    func extractTextFeature(from text: String) async throws -> [Float] {
        guard let model else { throw MobileCLIPTextError.textEncoderMissing }
        guard let tokenizer else { throw MobileCLIPTextError.tokenizerResourcesMissing }

        let ids = tokenizer.encode_full(text: text)
        guard ids.count == 77,
              let input = try? MLMultiArray(shape: [1, 77], dataType: .int32)
        else { throw MobileCLIPTextError.invalidEmbedding }
        for (index, id) in ids.enumerated() {
            input[index] = NSNumber(value: id)
        }

        return try await Task.detached(priority: .userInitiated) {
            guard let inputName = model.modelDescription.inputDescriptionsByName.first(where: {
                $0.value.type == .multiArray
            })?.key
            else { throw MobileCLIPTextError.invalidEmbedding }

            let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: input])
            let output = try model.prediction(from: provider)
            let outputName = ["final_emb_1", "embedding", "text_embedding"].first(where: {
                output.featureNames.contains($0)
            }) ?? output.featureNames.first(where: {
                output.featureValue(for: $0)?.multiArrayValue?.count == 512
            })
            guard let outputName,
                  let feature = output.featureValue(for: outputName)?.multiArrayValue,
                  feature.count == 512
            else { throw MobileCLIPTextError.invalidEmbedding }

            let vector = (0..<feature.count).map { feature[$0].floatValue }
            var squaredLength: Float = 0
            vDSP_svesq(vector, 1, &squaredLength, vDSP_Length(vector.count))
            let length = sqrt(squaredLength)
            guard length.isFinite, length > .leastNonzeroMagnitude else {
                throw MobileCLIPTextError.invalidEmbedding
            }
            return vector.map { $0 / length }
        }.value
    }
}

struct MobileCLIPCategoryPrompt: Sendable {
    let name: String
    let text: String

    init(name: String, text: String) {
        self.name = name
        self.text = text
    }
}

/// Builds the cache only from real MobileCLIP text embeddings. It is safe to
/// call on every launch because the work is skipped when a valid cache exists.
enum MobileCLIPCategoryEmbeddingBuilder {
    static let defaultPrompts = [
        MobileCLIPCategoryPrompt(name: "书本", text: "a photo of a book or notebook"),
        MobileCLIPCategoryPrompt(name: "电脑", text: "a photo of a laptop computer"),
        MobileCLIPCategoryPrompt(name: "手机", text: "a photo of a smartphone"),
        MobileCLIPCategoryPrompt(name: "键盘", text: "a photo of a computer keyboard"),
        MobileCLIPCategoryPrompt(name: "鼠标", text: "a photo of a computer mouse"),
        MobileCLIPCategoryPrompt(name: "文具", text: "a photo of stationery and pens"),
        MobileCLIPCategoryPrompt(name: "衣物", text: "a photo of clothes"),
        MobileCLIPCategoryPrompt(name: "鞋子", text: "a photo of a shoe"),
        MobileCLIPCategoryPrompt(name: "玩具", text: "a photo of a toy"),
        MobileCLIPCategoryPrompt(name: "工具", text: "a photo of a hand tool or household tool"),
        MobileCLIPCategoryPrompt(name: "收纳盒", text: "a photo of a storage box"),
        MobileCLIPCategoryPrompt(name: "餐具", text: "a photo of a bowl, plate, dish or kitchen utensil"),
        MobileCLIPCategoryPrompt(name: "杯子", text: "a photo of a drinking cup or mug"),
        MobileCLIPCategoryPrompt(name: "垃圾包装", text: "a photo of trash or packaging")
    ]

    static func ensureDefaultEmbeddings(
        vectorDB: CategoryVectorDB = .shared,
        extractor: MobileCLIPTextFeatureExtractor = .shared
    ) async {
        guard extractor.isAvailable else { return }
        let existing = Set(vectorDB.getAllCategories())
        let missingPrompts = defaultPrompts.filter { !existing.contains($0.name) }
        guard !missingPrompts.isEmpty else { return }

        for prompt in missingPrompts {
            guard let embedding = try? await extractor.extractTextFeature(from: prompt.text) else { continue }
            vectorDB.addCategory(name: prompt.name, embedding: embedding)
        }
        try? vectorDB.saveEmbeddingsToCache()
    }
}
