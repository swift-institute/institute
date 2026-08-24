import Foundation
import Institute_Model
import Institute_Source_Workspace
import JSON
import Source_Repair
import Testing
import Xcode_Workspace_Standard

@testable import Institute_Source

@Test
func `Institute repair plan round trips its complete workspace binding`() throws {
    let repair = Source.Repair.Plan(
        subject: .init(identity: "swift-primitives/swift-example", digest: "subject"),
        profile: .init("profile"),
        sources: .init("sources"),
        operations: [],
        refusals: [],
        postconditions: []
    )
    let plan = Institute.Source.Repair.Plan(
        workspace: "/workspace/institute interim.xcworkspace",
        workspaceDigest: "workspace",
        inventoryDigest: "inventory",
        cohort: ["swift-standards/swift-zeta", "swift-primitives/swift-example"],
        repairs: [repair]
    )

    let decoded = try Institute.Source.Repair.Plan(json: plan.json)

    #expect(decoded.workspace == plan.workspace)
    #expect(decoded.workspaceDigest == plan.workspaceDigest)
    #expect(decoded.inventoryDigest == plan.inventoryDigest)
    #expect(
        decoded.cohort == [
            "swift-standards/swift-zeta",
            "swift-primitives/swift-example",
        ]
    )
    #expect(decoded.repairs.map(\.subject) == [repair.subject])
    #expect(decoded.repairs.map(\.profile) == [repair.profile])
    #expect(decoded.repairs.map(\.sources) == [repair.sources])
}

@Test
func `Institute repair plan rejects unknown wrapper fields`() throws {
    let repair = Source.Repair.Plan(
        subject: .init(identity: "swift-primitives/swift-example", digest: "subject"),
        profile: .init("profile"),
        sources: .init("sources"),
        operations: [],
        refusals: [],
        postconditions: []
    )
    let plan = Institute.Source.Repair.Plan(
        workspace: "/workspace/institute interim.xcworkspace",
        workspaceDigest: "workspace",
        inventoryDigest: "inventory",
        cohort: ["swift-primitives/swift-example"],
        repairs: [repair]
    )
    var object = try #require(plan.json.dictionary)
    object["unknown"] = true.json

    #expect(throws: JSON.Error.self) {
        _ = try Institute.Source.Repair.Plan(
            json: .object(
                object.keys.sorted().compactMap { key in
                    object[key].map { (key, $0) }
                }
            )
        )
    }
}

@Test
func `Institute repair file system rejects path escape before IO`() {
    let files = Institute.Source.Application.fileSystem(root: "/tmp/source-repair-fixture")

    #expect(!files.exists("../outside"))
    guard case .failure(let reason) = files.read("../outside") else {
        Issue.record("expected path escape refusal")
        return
    }
    #expect(reason.code == "path-escape")
}

@Test
func `Institute source subject includes every Swift file outside build products`() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    for directory in ["Sources", "Tests/Unit", "Tests/Support", ".workspace/Member/Sources"] {
        try FileManager.default.createDirectory(
            at: root.appending(path: directory),
            withIntermediateDirectories: true
        )
    }
    for (path, contents) in [
        ("Package.swift", "// swift-tools-version: 6.4\n"),
        ("Sources/A.swift", "public enum A {}\n"),
        ("Tests/Unit/A Tests.swift", "import Testing\n"),
        ("Tests/Support/Fixture.swift", "struct Fixture {}\n"),
        (".workspace/Member/Sources/Residue.swift", "public enum Residue {}\n"),
    ] {
        try Data(contents.utf8).write(to: root.appending(path: path))
    }
    let row = Institute.Source.Workspace.Row(
        index: 0,
        location: .init(scheme: .group, path: "."),
        directory: root.path,
        identity: "swift-primitives/swift-example",
        role: .subject(
            try #require(Institute.Repository.Key(identity: "swift-primitives/swift-example"))
        ),
        repository: nil,
        reason: nil
    )

    let subject = try Institute.Source.Workspace.subject(
        for: row,
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
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    for directory in ["Sources", "Tests/Nested", "TestsSibling"] {
        try FileManager.default.createDirectory(
            at: root.appending(path: directory),
            withIntermediateDirectories: true
        )
    }
    for (path, contents) in [
        ("Package.swift", "// swift-tools-version: 6.4\n"),
        ("Package@swift-6.4.swift", "// swift-tools-version: 6.4\n"),
        ("Sources/Owned.swift", "public enum Owned {}\n"),
        ("Tests/Package.swift", "// swift-tools-version: 6.4\n"),
        ("Tests/Nested/Nested.swift", "public enum Nested {}\n"),
        ("TestsSibling/Owned.swift", "public enum Sibling {}\n"),
    ] {
        try Data(contents.utf8).write(to: root.appending(path: path))
    }
    let row = Institute.Source.Workspace.Row(
        index: 0,
        location: .init(scheme: .group, path: "."),
        directory: root.path,
        identity: "swift-foundations/swift-example",
        role: .subject(
            try #require(Institute.Repository.Key(identity: "swift-foundations/swift-example"))
        ),
        repository: nil,
        reason: nil
    )

    let subject = try Institute.Source.Workspace.subject(
        for: row,
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
