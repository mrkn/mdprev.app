import XCTest
@testable import mdprev

final class QuickLookRegistrationServiceTests: XCTestCase {
    func testCommandsIncludeLSRegisterAndPluginKitForInstalledAppBundle() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appURL = rootURL.appendingPathComponent("mdprev.app", isDirectory: true)
        let pluginURL = appURL.appendingPathComponent("Contents/PlugIns/mdprevQuickLook.appex", isDirectory: true)
        try FileManager.default.createDirectory(at: pluginURL, withIntermediateDirectories: true)

        let service = QuickLookRegistrationService(
            fileManager: .default,
            processRunner: RecordingProcessRunner(),
            bundleURL: appURL
        )

        let commands = service.commands()

        XCTAssertEqual(commands.count, 2)
        XCTAssertEqual(commands[0].executableURL.path, "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister")
        XCTAssertEqual(commands[0].arguments, ["-f", "-R", "-trusted", appURL.path])
        XCTAssertEqual(commands[1].executableURL.path, "/usr/bin/pluginkit")
        XCTAssertEqual(commands[1].arguments, ["-a", pluginURL.path])
    }

    func testCommandsAreEmptyWhenQuickLookExtensionIsMissing() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let appURL = rootURL.appendingPathComponent("mdprev.app", isDirectory: true)
        try FileManager.default.createDirectory(at: appURL, withIntermediateDirectories: true)

        let service = QuickLookRegistrationService(
            fileManager: .default,
            processRunner: RecordingProcessRunner(),
            bundleURL: appURL
        )

        XCTAssertTrue(service.commands().isEmpty)
    }
}

private final class RecordingProcessRunner: ProcessRunning {
    @discardableResult
    func run(executableURL: URL, arguments: [String]) throws -> Int32 {
        0
    }
}
