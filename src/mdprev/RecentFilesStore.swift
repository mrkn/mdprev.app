import Combine
import Foundation

@MainActor
final class RecentFilesStore: ObservableObject {
    static let maximumEntries = 10

    @Published private(set) var fileURLs: [URL]

    private let userDefaults: UserDefaults
    private let defaultsKey: String
    private let maxEntries: Int

    init(
        userDefaults: UserDefaults = .standard,
        defaultsKey: String = "recentFilePaths",
        maxEntries: Int = maximumEntries
    ) {
        self.userDefaults = userDefaults
        self.defaultsKey = defaultsKey
        self.maxEntries = max(1, maxEntries)
        let loadedURLs = Self.loadURLs(userDefaults: userDefaults, defaultsKey: defaultsKey)
        self.fileURLs = Array(loadedURLs.prefix(self.maxEntries))

        if self.fileURLs.count != loadedURLs.count {
            persist()
        }
    }

    func record(_ fileURL: URL) {
        let normalizedURL = Self.normalize(fileURL)
        fileURLs.removeAll { Self.normalize($0) == normalizedURL }
        fileURLs.insert(normalizedURL, at: 0)

        if fileURLs.count > maxEntries {
            fileURLs.removeSubrange(maxEntries...)
        }

        persist()
    }

    func remove(_ fileURL: URL) {
        let normalizedURL = Self.normalize(fileURL)
        fileURLs.removeAll { Self.normalize($0) == normalizedURL }
        persist()
    }

    func clear() {
        fileURLs.removeAll()
        persist()
    }

    private func persist() {
        let paths = fileURLs.prefix(maxEntries).map { Self.normalize($0).path }
        userDefaults.set(Array(paths), forKey: defaultsKey)
    }

    private static func loadURLs(userDefaults: UserDefaults, defaultsKey: String) -> [URL] {
        guard let paths = userDefaults.array(forKey: defaultsKey) as? [String] else {
            return []
        }

        var seen = Set<String>()
        var urls: [URL] = []
        for path in paths {
            let url = normalize(URL(fileURLWithPath: path))
            if seen.insert(url.path).inserted {
                urls.append(url)
            }
        }
        return urls
    }

    private static func normalize(_ fileURL: URL) -> URL {
        fileURL.standardizedFileURL.resolvingSymlinksInPath()
    }
}
