import Foundation

protocol ProcessRunning {
    @discardableResult
    func run(executableURL: URL, arguments: [String]) throws -> Int32
}

struct ProcessRunner: ProcessRunning {
    @discardableResult
    func run(executableURL: URL, arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        return process.terminationStatus
    }
}

struct QuickLookRegistrationCommand: Equatable {
    let executableURL: URL
    let arguments: [String]
}

struct QuickLookRegistrationService {
    private let fileManager: FileManager
    private let processRunner: ProcessRunning
    private let bundleURL: URL

    init(
        fileManager: FileManager = .default,
        processRunner: ProcessRunning = ProcessRunner(),
        bundleURL: URL = Bundle.main.bundleURL
    ) {
        self.fileManager = fileManager
        self.processRunner = processRunner
        self.bundleURL = bundleURL
    }

    func registerIfPossible() {
        for command in commands() {
            do {
                _ = try processRunner.run(
                    executableURL: command.executableURL,
                    arguments: command.arguments
                )
            } catch {
                continue
            }
        }
    }

    func commands() -> [QuickLookRegistrationCommand] {
        let bundleURL = bundleURL.standardizedFileURLIfPossible
        guard fileManager.fileExists(atPath: bundleURL.path),
              bundleURL.pathExtension == "app"
        else {
            return []
        }

        let quickLookExtensionURL = bundleURL
            .appendingPathComponent("Contents/PlugIns/mdprevQuickLook.appex")

        guard fileManager.fileExists(atPath: quickLookExtensionURL.path) else {
            return []
        }

        return [
            QuickLookRegistrationCommand(
                executableURL: URL(fileURLWithPath: "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"),
                arguments: ["-f", "-R", "-trusted", bundleURL.path]
            ),
            QuickLookRegistrationCommand(
                executableURL: URL(fileURLWithPath: "/usr/bin/pluginkit"),
                arguments: ["-a", quickLookExtensionURL.path]
            )
        ]
    }
}

private extension URL {
    var standardizedFileURLIfPossible: URL {
        isFileURL ? standardizedFileURL : self
    }
}
