import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english
    case chinese

    var id: String { rawValue }

    var localeIdentifier: String {
        switch self {
        case .english: "en"
        case .chinese: "zh-Hans"
        }
    }

    var displayName: String {
        switch self {
        case .english: "English"
        case .chinese: "中文"
        }
    }
}
