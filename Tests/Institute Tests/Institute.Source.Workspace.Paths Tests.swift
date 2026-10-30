import Institute_Model
import Institute_Source_Workspace
import Source_Measurement
import Testing

@Test
func `Institute source subject includes every Swift file outside build products`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    defer { try? MainFixtureFiles.remove(root) }
    for directory in ["Sources", "Tests/Unit", "Tests/Support", ".workspace/Member/Sources"] {
        try MainFixtureFiles.createDirectory(MainFixtureFiles.join(root, directory))
    }
    for (path, contents) in [
        ("Package.swift", "// swift-tools-version: 6.4\n"),
        ("Sources/A.swift", "public enum A {}\n"),
        ("Tests/Unit/A Tests.swift", "import Testing\n"),
        ("Tests/Support/Fixture.swift", "struct Fixture {}\n"),
        (".workspace/Member/Sources/Residue.swift", "public enum Residue {}\n"),
    ] {
        try MainFixtureFiles.write(bytes: Array(contents.utf8), to: MainFixtureFiles.join(root, path))
    }
    let subject = try Institute.Source.Workspace.subject(
        identity: "swift-atoms/swift-example",
        root: root,
        paths: [
            "Package.swift",
            "Sources/A.swift",
            "Tests/Unit/A Tests.swift",
            "Tests/Support/Fixture.swift",
        ]
    )

    #expect(
        subject.paths(of: .swift) == [
            "Package.swift",
            "Sources/A.swift",
            "Tests/Support/Fixture.swift",
            "Tests/Unit/A Tests.swift",
        ]
    )
}

@Test
func `Institute source subject excludes descendant package ownership`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    defer { try? MainFixtureFiles.remove(root) }
    for directory in ["Sources", "Tests/Nested", "TestsSibling"] {
        try MainFixtureFiles.createDirectory(MainFixtureFiles.join(root, directory))
    }
    for (path, contents) in [
        ("Package.swift", "// swift-tools-version: 6.4\n"),
        ("Package@swift-6.4.swift", "// swift-tools-version: 6.4\n"),
        ("Sources/Owned.swift", "public enum Owned {}\n"),
        ("Tests/Package.swift", "// swift-tools-version: 6.4\nimport PackageDescription\nlet package = Package(name: \"testing\")\n"),
        ("Tests/Nested/Nested.swift", "public enum Nested {}\n"),
        ("TestsSibling/Owned.swift", "public enum Sibling {}\n"),
    ] {
        try MainFixtureFiles.write(bytes: Array(contents.utf8), to: MainFixtureFiles.join(root, path))
    }
    let subject = try Institute.Source.Workspace.subject(
        identity: "swift-compositions/swift-example",
        root: root,
        paths: [
            "Package.swift",
            "Package@swift-6.4.swift",
            "Sources/Owned.swift",
            "Tests/Package.swift",
            "Tests/Nested/Nested.swift",
            "TestsSibling/Owned.swift",
        ]
    )

    #expect(
        subject.paths(of: .swift) == [
            "Package.swift",
            "Package@swift-6.4.swift",
            "Sources/Owned.swift",
            "TestsSibling/Owned.swift",
        ]
    )
}

@Test
func `Institute source subject keeps a Package.swift that is not a manifest`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    defer { try? MainFixtureFiles.remove(root) }
    for directory in ["Sources/Package", "Tests/Fixtures/plain"] {
        try MainFixtureFiles.createDirectory(MainFixtureFiles.join(root, directory))
    }
    for (path, contents) in [
        ("Package.swift", "// swift-tools-version: 6.4\nimport PackageDescription\n"),
        ("Sources/Package/Package.swift", "public enum Package {}\n"),
        ("Sources/Package/Name.swift", "extension Package { public enum Name {} }\n"),
        ("Tests/Fixtures/plain/Package.swift", "// swift-tools-version: 6.3\n"),
        ("Tests/Fixtures/plain/Fixture.swift", "public enum Fixture {}\n"),
    ] {
        try MainFixtureFiles.write(bytes: Array(contents.utf8), to: MainFixtureFiles.join(root, path))
    }
    let subject = try Institute.Source.Workspace.subject(
        identity: "swift-compositions/swift-example",
        root: root,
        paths: [
            "Package.swift",
            "Sources/Package/Name.swift",
            "Sources/Package/Package.swift",
            "Tests/Fixtures/plain/Fixture.swift",
            "Tests/Fixtures/plain/Package.swift",
        ]
    )

    // Neither nested Package.swift is a manifest, so nothing is pruned: the same
    // file set swift-linter measures.
    #expect(
        subject.paths(of: .swift) == [
            "Package.swift",
            "Sources/Package/Name.swift",
            "Sources/Package/Package.swift",
            "Tests/Fixtures/plain/Fixture.swift",
            "Tests/Fixtures/plain/Package.swift",
        ]
    )
}
