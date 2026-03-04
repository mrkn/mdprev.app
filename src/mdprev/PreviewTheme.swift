import Foundation

enum PreviewTheme: String, CaseIterable, Codable {
    case system
    case light
    case dark
    case sepia

    static let defaultTheme: PreviewTheme = .system

    init(storedValue: String?) {
        if let storedValue, let value = PreviewTheme(rawValue: storedValue) {
            self = value
        } else {
            self = Self.defaultTheme
        }
    }

    var displayName: String {
        switch self {
        case .system:
            return "System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        case .sepia:
            return "Sepia"
        }
    }
}
