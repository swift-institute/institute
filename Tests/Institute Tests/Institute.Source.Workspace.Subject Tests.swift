import Foundation
import Git_Foundation
import Institute_Model
import Institute_Source_Workspace
import Testing

@Test
func `Package source subject binds the exact clean revision`() throws {
    let fixture = try sourcePackageFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }

    let subject = try Institute.Source.Workspace.subject(
        repository: "swift-standards/swift-example",
        revision: fixture.revision,
        root: fixture.root.path
    )

    #expect(subject.identity == "swift-standards/swift-example@\(fixture.revision)")
}

@Test
func `Package source subject refuses a claimed revision that is not HEAD`() throws {
    let fixture = try sourcePackageFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }

    #expect(throws: Institute.Error.self) {
        _ = try Institute.Source.Workspace.subject(
            repository: "swift-standards/swift-example",
            revision: String(repeating: "0", count: 40),
            root: fixture.root.path
        )
    }
}

@Test
func `Package source subject refuses changes outside the claimed revision`() throws {
    let fixture = try sourcePackageFixture()
    defer { try? FileManager.default.removeItem(at: fixture.root) }
    try "// changed\n".write(
        to: fixture.root.appending(path: "Package.swift"),
        atomically: true,
        encoding: .utf8
    )

    #expect(throws: Institute.Error.self) {
        _ = try Institute.Source.Workspace.subject(
            repository: "swift-standards/swift-example",
            revision: fixture.revision,
            root: fixture.root.path
        )
    }
}

private func sourcePackageFixture() throws -> (root: URL, revision: Swift.String) {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(
        at: root.appending(path: "Sources"),
        withIntermediateDirectories: true
    )
    try "// swift-tools-version: 6.4\n".write(
        to: root.appending(path: "Package.swift"),
        atomically: true,
        encoding: .utf8
    )
    try "public enum Example {}\n".write(
        to: root.appending(path: "Sources/Example.swift"),
        atomically: true,
        encoding: .utf8
    )
    let git = Git.Client()
    try git.initialize(at: root.path, bare: false)
    try sourceGit(["config", "user.email", "workspace@swift.institute"], at: root)
    try sourceGit(["config", "user.name", "Institute Tests"], at: root)
    try sourceGit(["add", "Package.swift", "Sources/Example.swift"], at: root)
    try sourceGit(["commit", "-m", "Fixture package"], at: root)
    return (root, try git.head(at: root.path).rawValue)
}

private func sourceGit(_ arguments: [Swift.String], at root: URL) throws {
    let process = Foundation.Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = arguments
    process.currentDirectoryURL = root
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        throw CocoaError(.executableNotLoadable)
    }
}
