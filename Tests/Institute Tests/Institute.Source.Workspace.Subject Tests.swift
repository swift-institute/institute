import Git_Foundation
import Institute_Model
import Institute_Source_Workspace
import Source_Measurement
import Testing

@Test
func `Package source subject binds the exact clean revision`() throws {
    let fixture = try sourcePackageFixture()
    defer { try? MainFixtureFiles.remove(fixture.root) }

    let subject = try Institute.Source.Workspace.subject(
        repository: "swift-standards/swift-example",
        revision: fixture.revision,
        root: fixture.root
    )

    #expect(subject.identity == "swift-standards/swift-example@\(fixture.revision)")
}

@Test
func `Package source subject refuses a claimed revision that is not HEAD`() throws {
    let fixture = try sourcePackageFixture()
    defer { try? MainFixtureFiles.remove(fixture.root) }

    #expect(throws: Institute.Error.self) {
        _ = try Institute.Source.Workspace.subject(
            repository: "swift-standards/swift-example",
            revision: String(repeating: "0", count: 40),
            root: fixture.root
        )
    }
}

@Test
func `Package source subject refuses changes outside the claimed revision`() throws {
    let fixture = try sourcePackageFixture()
    defer { try? MainFixtureFiles.remove(fixture.root) }
    try MainFixtureFiles.write("// changed\n", toURLPath: MainFixtureFiles.join(fixture.root, "Package.swift"))

    #expect(throws: Institute.Error.self) {
        _ = try Institute.Source.Workspace.subject(
            repository: "swift-standards/swift-example",
            revision: fixture.revision,
            root: fixture.root
        )
    }
}

private func sourcePackageFixture() throws -> (root: Swift.String, revision: Swift.String) {
    let rootName = MainFixtureFiles.uniqueName()
    let root = MainFixtureFiles.temporaryPath(rootName)
    try MainFixtureFiles.createDirectory(MainFixtureFiles.join(root, "Sources"))
    try MainFixtureFiles.write("// swift-tools-version: 6.4\n", toURLPath: MainFixtureFiles.join(root, "Package.swift"))
    try MainFixtureFiles.write("public enum Example {}\n", toURLPath: MainFixtureFiles.join(root, "Sources/Example.swift"))
    let git = Git.Client()
    try git.initialize(at: root, bare: false)
    try sourceGit(["config", "user.email", "workspace@swift.institute"], temporaryName: rootName)
    try sourceGit(["config", "user.name", "Institute Tests"], temporaryName: rootName)
    try sourceGit(["add", "Package.swift", "Sources/Example.swift"], temporaryName: rootName)
    try sourceGit(["commit", "-m", "Fixture package"], temporaryName: rootName)
    return (root, try git.head(at: root).rawValue)
}

private func sourceGit(_ arguments: [Swift.String], temporaryName: Swift.String) throws {
    try MainFixtureFiles.gitRequiringSuccess(arguments, inTemporary: temporaryName)
}
