import Foundation
import Institute_Model
import Institute_Source_Policy
import JSON
import Source_Profile
import Source_Report
import Synchronization
import Testing

@testable import Institute_Source

@Test
func `Institute source preparation round trips its parse receipt`() throws {
    let preparation = Institute.Source.Preparation(
        policyRevision: "source-enforcement-v3",
        workspaceDigest: "workspace-digest",
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format-tool"),
        linterExecutable: "/tools/swift-linter",
        linter: .init(
            origin: .published(asset: "swift-linter-macos-arm64"),
            digest: .init("linter-tool")
        ),
        directory: "/artifacts/.source",
        profiles: ["institute": .init("profile-digest")],
        verifiedProfiles: ["institute"]
    )

    let decoded = try Institute.Source.Preparation(
        jsonString: preparation.jsonString(sortKeys: true)
    )

    #expect(decoded.policyRevision == preparation.policyRevision)
    #expect(decoded.workspaceDigest == preparation.workspaceDigest)
    #expect(decoded.swiftFormatExecutable == preparation.swiftFormatExecutable)
    #expect(decoded.swiftFormatTool == preparation.swiftFormatTool)
    #expect(decoded.linterExecutable == preparation.linterExecutable)
    #expect(decoded.linterTool == preparation.linterTool)
    #expect(decoded.linter.origin == .published(asset: "swift-linter-macos-arm64"))
    #expect(decoded.directory == preparation.directory)
    #expect(decoded.profiles == preparation.profiles)
    #expect(decoded.verifiedProfiles == ["institute"])
}

@Test
func `Institute source preparation rejects receipts without a parse verdict`() throws {
    let preparation = Institute.Source.Preparation(
        policyRevision: "source-enforcement-v3",
        workspaceDigest: "workspace-digest",
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format-tool"),
        linterExecutable: "/tools/swift-linter",
        linter: .init(origin: .local, digest: .init("linter-tool")),
        directory: "/artifacts/.source",
        profiles: [:],
        verifiedProfiles: []
    )
    var object = try #require(preparation.json.dictionary)
    object["verifiedProfiles"] = nil

    #expect(throws: JSON.Error.self) {
        _ = try Institute.Source.Preparation(
            jsonString: JSON.object(
                object.keys.sorted().compactMap { key in
                    object[key].map { (key, $0) }
                }
            ).jsonString(sortKeys: true)
        )
    }
}

@Test
func `Institute profile verification passes exactly on the engine's silent zero`() async throws {
    let recorded = Mutex<[[Swift.String]]>([])
    let process = Source.Engine.Process { _, arguments, _, environment in
        recorded.withLock { $0.append(arguments) }
        #expect(environment["SWIFT_LINTER_BUNDLE"] == "institute")
        return .init(status: 0, output: "", diagnostics: "")
    }

    try await Institute.Source.Application.verify(
        profile: "/artifacts/.source/institute-source-linter-profile.json",
        bundle: .institute,
        linterExecutable: "/tools/swift-linter",
        directory: "/artifacts/.source",
        process: process
    )

    #expect(
        recorded.withLock { $0 } == [
            ["--profile-check", "/artifacts/.source/institute-source-linter-profile.json"]
        ]
    )
}

@Test
func `Institute profile verification fails loudly on an engine refusal`() async {
    let process = Source.Engine.Process { _, _, _, _ in
        .init(
            status: 1,
            output: "",
            diagnostics: "[Lint] error: profile: malformed(\"Type mismatch\")"
        )
    }

    await #expect(throws: Institute.Error.self) {
        try await Institute.Source.Application.verify(
            profile: "/artifacts/.source/institute-source-linter-profile.json",
            bundle: .institute,
            linterExecutable: "/tools/swift-linter",
            directory: "/artifacts/.source",
            process: process
        )
    }
}

@Test
func `Local source linter snapshot is content addressed and omits its input path from receipt`() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let tools = root.appending(path: "tools")
    let input = root.appending(path: "developer-build")
    try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
    try Data("local-linter".utf8).write(to: input)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: input.path)
    defer { try? FileManager.default.removeItem(at: root) }

    let process = Source.Engine.Process { _, _, _, _ in
        .init(status: 0, output: "", diagnostics: "")
    }
    let acquisition = Institute.Source.Acquisition(process: process)
    let snapshot = try acquisition.snapshot(
        executable: input.path,
        into: try File.Directory(validating: tools.path)
    )
    let preparation = Institute.Source.Preparation(
        policyRevision: "source-enforcement-v3",
        workspaceDigest: "workspace-digest",
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format-tool"),
        linterExecutable: snapshot.file.description,
        linter: .init(origin: .local, digest: snapshot.digest),
        directory: root.path,
        profiles: [:],
        verifiedProfiles: []
    )
    let receipt = preparation.jsonString(sortKeys: true)

    #expect(snapshot.file.path.components.last?.string == "swift-linter-local-\(snapshot.digest.hex)")
    #expect(try Data(contentsOf: URL(filePath: snapshot.file.description)) == Data("local-linter".utf8))
    #expect(
        try FileManager.default.attributesOfItem(atPath: snapshot.file.description)[.posixPermissions]
            as? Int == 0o755
    )
    #expect(receipt.contains("\"kind\":\"local\""))
    #expect(!receipt.contains(input.path))
    let decoded = try Institute.Source.Preparation(jsonString: receipt)
    #expect(decoded.linter.origin == .local)
    #expect(decoded.linterTool == snapshot.digest)
    #expect(decoded.linterExecutable == snapshot.file.description)
}

@Test
func `Local source linter snapshot refuses missing non-file and non-executable inputs`() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let tools = root.appending(path: "tools")
    let directoryInput = root.appending(path: "directory")
    let nonExecutable = root.appending(path: "non-executable")
    try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: directoryInput, withIntermediateDirectories: true)
    try Data("bytes".utf8).write(to: nonExecutable)
    try FileManager.default.setAttributes(
        [.posixPermissions: 0o644],
        ofItemAtPath: nonExecutable.path
    )
    defer { try? FileManager.default.removeItem(at: root) }

    let process = Source.Engine.Process { _, _, _, _ in
        .init(status: 0, output: "", diagnostics: "")
    }
    let acquisition = Institute.Source.Acquisition(process: process)
    let destination = try File.Directory(validating: tools.path)

    #expect(throws: Institute.Error.self) {
        _ = try acquisition.snapshot(
            executable: root.appending(path: "missing").path,
            into: destination
        )
    }
    #expect(throws: Institute.Error.self) {
        _ = try acquisition.snapshot(executable: directoryInput.path, into: destination)
    }
    #expect(throws: Institute.Error.self) {
        _ = try acquisition.snapshot(executable: nonExecutable.path, into: destination)
    }
}

@Test
func `Different local source linter bytes change tool and profile identity`() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let tools = root.appending(path: "tools")
    let first = root.appending(path: "first")
    let second = root.appending(path: "second")
    try FileManager.default.createDirectory(at: tools, withIntermediateDirectories: true)
    try Data("first-linter".utf8).write(to: first)
    try Data("second-linter".utf8).write(to: second)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: first.path)
    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: second.path)
    defer { try? FileManager.default.removeItem(at: root) }

    let process = Source.Engine.Process { _, _, _, _ in
        .init(status: 0, output: "", diagnostics: "")
    }
    let acquisition = Institute.Source.Acquisition(process: process)
    let destination = try File.Directory(validating: tools.path)
    let firstSnapshot = try acquisition.snapshot(executable: first.path, into: destination)
    let secondSnapshot = try acquisition.snapshot(executable: second.path, into: destination)
    let policy = Institute.Source.Policy.current
    let rules = Institute.Source.Profile(policy: policy).rules(for: .institute)
    let firstProfile = policy.profile(
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format"),
        swiftFormatConfigurationPath: "/profile/.swift-format",
        linterExecutable: firstSnapshot.file.description,
        linterTool: firstSnapshot.digest,
        linterConfigurationPath: "/profile/institute-source-linter-profile.json",
        bundle: .institute,
        linterRules: rules
    )
    let secondProfile = policy.profile(
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format"),
        swiftFormatConfigurationPath: "/profile/.swift-format",
        linterExecutable: secondSnapshot.file.description,
        linterTool: secondSnapshot.digest,
        linterConfigurationPath: "/profile/institute-source-linter-profile.json",
        bundle: .institute,
        linterRules: rules
    )

    #expect(firstSnapshot.digest != secondSnapshot.digest)
    #expect(firstSnapshot.file.description != secondSnapshot.file.description)
    #expect(firstProfile.digest != secondProfile.digest)
}

@Test
func `Source measurement refuses a tampered local linter snapshot`() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let format = root.appending(path: "swift-format")
    let linter = root.appending(path: "swift-linter-local")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    try Data("format".utf8).write(to: format)
    try Data("linter".utf8).write(to: linter)
    defer { try? FileManager.default.removeItem(at: root) }

    let preparation = Institute.Source.Preparation(
        policyRevision: Institute.Source.Policy.current.revision,
        workspaceDigest: "workspace",
        swiftFormatExecutable: format.path,
        swiftFormatTool: try Institute.Source.Application.digest(file: format.path),
        linterExecutable: linter.path,
        linter: .init(
            origin: .local,
            digest: try Institute.Source.Application.digest(file: linter.path)
        ),
        directory: root.path,
        profiles: [:],
        verifiedProfiles: []
    )
    try Data("tampered".utf8).write(to: linter)
    let cohort = Institute.Source.Workspace.Cohort(
        workspace: "/workspace",
        references: 0,
        groupReferences: 0,
        containerReferences: 0,
        rows: [],
        reasons: []
    )
    let report = try await Institute.Source.Application().measure(
        cohort: cohort,
        preparation: preparation
    )

    #expect(report.references.contains { $0.code == "stale-tool" })
}
