import Darwin
import Foundation

enum FileWatcherError: LocalizedError {
    case failedToOpenDirectory(String)
    case watcherAlreadyStarted

    var errorDescription: String? {
        switch self {
        case .failedToOpenDirectory(let path):
            return "Could not open directory for watch: \(path)"
        case .watcherAlreadyStarted:
            return "Watcher is already running"
        }
    }
}

struct FileSnapshot: Equatable {
    let exists: Bool
    let modifiedAt: Date?
    let size: UInt64?
    let inode: UInt64?

    static func capture(at fileURL: URL) -> FileSnapshot {
        let path = fileURL.path

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return FileSnapshot(exists: false, modifiedAt: nil, size: nil, inode: nil)
        }

        return FileSnapshot(
            exists: true,
            modifiedAt: attributes[.modificationDate] as? Date,
            size: (attributes[.size] as? NSNumber)?.uint64Value,
            inode: (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
        )
    }
}

final class FileWatcher {
    private let fileURL: URL
    private let callback: @Sendable () -> Void
    private let queue = DispatchQueue(label: "mdprev.file-watcher")
    private var source: DispatchSourceFileSystemObject?
    private var pendingWorkItem: DispatchWorkItem?
    private var lastSnapshot: FileSnapshot

    init(fileURL: URL, callback: @escaping @Sendable () -> Void) throws {
        self.fileURL = fileURL.standardizedFileURL
        self.callback = callback
        self.lastSnapshot = FileSnapshot.capture(at: self.fileURL)
    }

    deinit {
        stop()
    }

    func start() throws {
        guard source == nil else {
            throw FileWatcherError.watcherAlreadyStarted
        }

        let directoryURL = fileURL.deletingLastPathComponent()
        let descriptor = open(directoryURL.path, O_EVTONLY)

        guard descriptor >= 0 else {
            throw FileWatcherError.failedToOpenDirectory(directoryURL.path)
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .attrib, .rename, .delete, .link, .revoke],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleCheck()
        }

        source.setCancelHandler {
            close(descriptor)
        }

        self.source = source
        source.resume()
    }

    func stop() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil

        source?.cancel()
        source = nil
    }

    private func scheduleCheck() {
        pendingWorkItem?.cancel()

        let work = DispatchWorkItem { [weak self] in
            self?.emitIfChanged()
        }

        pendingWorkItem = work
        queue.asyncAfter(deadline: .now() + .milliseconds(200), execute: work)
    }

    private func emitIfChanged() {
        let currentSnapshot = FileSnapshot.capture(at: fileURL)

        guard currentSnapshot != lastSnapshot else {
            return
        }

        lastSnapshot = currentSnapshot
        callback()
    }
}
