import Foundation

public enum PreviewTheme: String, CaseIterable, Codable, Sendable {
    case system
    case light
    case dark
    case sepia

    public static let defaultTheme: PreviewTheme = .system

    public init(storedValue: String?) {
        if let storedValue, let value = PreviewTheme(rawValue: storedValue) {
            self = value
        } else {
            self = Self.defaultTheme
        }
    }

    public var displayName: String {
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
