import File_System
import Foundation
import Git_Foundation

@testable import Institute_Model
@testable import Institute_Inventory
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Lint
@testable import Institute_Pages
@testable import Institute_Doctor
@testable import Institute_Conversion
@testable import Institute_Instruments

extension Institute.Inventory.Test {
    struct Fixture {
        let location: URL
        let root: File.Directory
        let file: URL
        let git: Git.Client

        init(configuration: Institute.Configuration) throws {
            location =
                FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try FileManager.default.createDirectory(
                at: location,
                withIntermediateDirectories: true
            )
            root = try File.Directory(validating: location.path)
            file = location.appending(path: "Institute.json")
            git = .init()

            try Data(configuration.rendered().utf8).write(to: file, options: .atomic)
            try git.initialize(at: location.path, bare: false)
            try Self.execute(
                ["config", "user.email", "workspace@swift.institute"],
                at: location
            )
            try Self.execute(
                ["config", "user.name", "Institute Tests"],
                at: location
            )
            try Self.execute(["add", "Institute.json"], at: location)
            try Self.execute(["commit", "-m", "Fixture inventory"], at: location)
        }
    }
}

extension Institute.Inventory.Test.Fixture {
    func remove() {
        try? FileManager.default.removeItem(at: location)
    }

    private static func execute(_ arguments: [Swift.String], at directory: URL) throws {
        let process = Foundation.Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.executableNotLoadable)
        }
    }
}
