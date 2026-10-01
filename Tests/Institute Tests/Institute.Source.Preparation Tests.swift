import File_System
import Institute_Model
import Institute_Source_Policy
import Institute_Source_Profile
import Institute_Source_Workspace
import JSON
import Source_Profile
import Source_Repair
import Source_Report
import Synchronization
import Testing

@testable import Institute_Source

@Test
func `Institute source preparation round trips its parse receipt`() throws {
    let preparation = Institute.Source.Preparation(
        policyRevision: "source-enforcement-v3",
        binding: .workspace(digest: "workspace-digest"),
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format-tool"),
        swiftLintExecutable: "/tools/swiftlint",
        swiftLint: .init(
            origin: .published(asset: "swiftlint"),
            digest: .init("swiftlint-tool")
        ),
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
    #expect(decoded.binding == preparation.binding)
    #expect(decoded.swiftFormatExecutable == preparation.swiftFormatExecutable)
    #expect(decoded.swiftFormatTool == preparation.swiftFormatTool)
    #expect(decoded.swiftLintExecutable == preparation.swiftLintExecutable)
    #expect(decoded.swiftLintTool == preparation.swiftLintTool)
    #expect(decoded.swiftLint.origin == .published(asset: "swiftlint"))
    #expect(decoded.linterExecutable == preparation.linterExecutable)
    #expect(decoded.linterTool == preparation.linterTool)
    #expect(decoded.linter.origin == .published(asset: "swift-linter-macos-arm64"))
    #expect(decoded.directory == preparation.directory)
    #expect(decoded.profiles == preparation.profiles)
    #expect(decoded.verifiedProfiles == ["institute"])
}

@Test
func `Institute source preparation binds one exact package subject`() throws {
    let binding = Institute.Source.Preparation.Binding.package(
        .init(identity: "swift-standards/swift-iso-639@revision", digest: "subject-digest")
    )
    let preparation = Institute.Source.Preparation(
        policyRevision: "source-enforcement-v3",
        binding: binding,
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format-tool"),
        swiftLintExecutable: "/tools/swiftlint",
        swiftLint: .init(origin: .local, digest: .init("swiftlint-tool")),
        linterExecutable: "/tools/swift-linter",
        linter: .init(origin: .local, digest: .init("linter-tool")),
        directory: "/package/.source",
        profiles: [:],
        verifiedProfiles: []
    )

    let decoded = try Institute.Source.Preparation(
        jsonString: preparation.jsonString(sortKeys: true)
    )

    #expect(decoded.binding == binding)
}

@Test
func `Institute source preparation rejects receipts without a parse verdict`() throws {
    let preparation = Institute.Source.Preparation(
        policyRevision: "source-enforcement-v3",
        binding: .workspace(digest: "workspace-digest"),
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format-tool"),
        swiftLintExecutable: "/tools/swiftlint",
        swiftLint: .init(origin: .local, digest: .init("swiftlint-tool")),
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
func `Xcode source acquisition reports expected and observed identity`() async throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    try MainFixtureFiles.createDirectory(root)
    defer { try? MainFixtureFiles.remove(root) }

    let process = Source.Engine.Process { _, arguments, _, _ in
        .init(
            status: 0,
            output: arguments.contains("CFBundleShortVersionString") ? "27.0" : "27A5228h",
            diagnostics: ""
        )
    }
    let acquisition = Institute.Source.Acquisition(process: process)
    let asset = Institute.Source.Policy.Asset(
        name: "swift-format",
        digest: .init("unused"),
        origin: .xcode(
            application: "/Applications/Synthetic.app",
            version: "27.0",
            build: "27A5237l",
            relativePath:
                "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format"
        )
    )

    let destination = try File.Directory(validating: root)
    do throws(Institute.Error) {
        _ = try await acquisition.acquire(
            asset,
            executable: true,
            into: destination
        )
        Issue.record("mismatched Xcode build identity was accepted")
    } catch {
        #expect(
            error.description
                == "pinned Xcode identity mismatch for ProductBuildVersion: "
                + "expected 27A5237l, observed 27A5228h"
        )
    }
}

@Test
func `Xcode source acquisition reports exact identity read failure`() async throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    try MainFixtureFiles.createDirectory(root)
    defer { try? MainFixtureFiles.remove(root) }

    let process = Source.Engine.Process { _, _, _, _ in
        .init(status: 1, output: "", diagnostics: "missing version plist")
    }
    let acquisition = Institute.Source.Acquisition(process: process)
    let asset = Institute.Source.Policy.Asset(
        name: "swift-format",
        digest: .init("unused"),
        origin: .xcode(
            application: "/Applications/Synthetic.app",
            version: "27.0",
            build: "27A5228h",
            relativePath:
                "Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift-format"
        )
    )

    let destination = try File.Directory(validating: root)
    do throws(Institute.Error) {
        _ = try await acquisition.acquire(
            asset,
            executable: true,
            into: destination
        )
        Issue.record("unreadable Xcode identity was accepted")
    } catch {
        #expect(
            error.description
                == "cannot read pinned Xcode identity CFBundleShortVersionString: "
                + "plutil exited 1: missing version plist"
        )
    }
}

@Test
func `Local source linter snapshot is content addressed and omits its input path from receipt`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    let tools = MainFixtureFiles.join(root, "tools")
    let input = MainFixtureFiles.join(root, "developer-build")
    try MainFixtureFiles.createDirectory(tools)
    try MainFixtureFiles.write(bytes: Array("local-linter".utf8), to: input)
    try MainFixtureFiles.setPermissions(input, posix: 0o755)
    defer { try? MainFixtureFiles.remove(root) }

    let process = Source.Engine.Process { _, _, _, _ in
        .init(status: 0, output: "", diagnostics: "")
    }
    let acquisition = Institute.Source.Acquisition(process: process)
    let snapshot = try acquisition.snapshot(
        executable: input,
        name: "swift-linter",
        into: try File.Directory(validating: tools)
    )
    let preparation = Institute.Source.Preparation(
        policyRevision: "source-enforcement-v3",
        binding: .workspace(digest: "workspace-digest"),
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format-tool"),
        swiftLintExecutable: "/tools/swiftlint",
        swiftLint: .init(origin: .local, digest: .init("swiftlint-tool")),
        linterExecutable: snapshot.file.description,
        linter: .init(origin: .local, digest: snapshot.digest),
        directory: root,
        profiles: [:],
        verifiedProfiles: []
    )
    let receipt = preparation.jsonString(sortKeys: true)

    #expect(snapshot.file.path.components.last?.string == "swift-linter-local-\(snapshot.digest.hex)")
    #expect(try MainFixtureFiles.readBytes(snapshot.file.description) == Array("local-linter".utf8))
    #expect(
        try MainFixtureFiles.posixPermissions(snapshot.file.description) == 0o755
    )
    #expect(receipt.contains("\"kind\":\"local\""))
    #expect(!receipt.contains(input))
    let decoded = try Institute.Source.Preparation(jsonString: receipt)
    #expect(decoded.linter.origin == .local)
    #expect(decoded.linterTool == snapshot.digest)
    #expect(decoded.linterExecutable == snapshot.file.description)
}

@Test
func `Local source linter snapshot refuses missing non-file and non-executable inputs`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    let tools = MainFixtureFiles.join(root, "tools")
    let directoryInput = MainFixtureFiles.join(root, "directory")
    let nonExecutable = MainFixtureFiles.join(root, "non-executable")
    try MainFixtureFiles.createDirectory(tools)
    try MainFixtureFiles.createDirectory(directoryInput)
    try MainFixtureFiles.write(bytes: Array("bytes".utf8), to: nonExecutable)
    try MainFixtureFiles.setPermissions(nonExecutable, posix: 0o644)
    defer { try? MainFixtureFiles.remove(root) }

    let process = Source.Engine.Process { _, _, _, _ in
        .init(status: 0, output: "", diagnostics: "")
    }
    let acquisition = Institute.Source.Acquisition(process: process)
    let destination = try File.Directory(validating: tools)

    #expect(throws: Institute.Error.self) {
        _ = try acquisition.snapshot(
            executable: MainFixtureFiles.join(root, "missing"),
            name: "swift-linter",
            into: destination
        )
    }
    #expect(throws: Institute.Error.self) {
        _ = try acquisition.snapshot(
            executable: directoryInput,
            name: "swift-linter",
            into: destination
        )
    }
    #expect(throws: Institute.Error.self) {
        _ = try acquisition.snapshot(
            executable: nonExecutable,
            name: "swift-linter",
            into: destination
        )
    }
}

@Test
func `Different local source linter bytes change tool and profile identity`() throws {
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    let tools = MainFixtureFiles.join(root, "tools")
    let first = MainFixtureFiles.join(root, "first")
    let second = MainFixtureFiles.join(root, "second")
    try MainFixtureFiles.createDirectory(tools)
    try MainFixtureFiles.write(bytes: Array("first-linter".utf8), to: first)
    try MainFixtureFiles.write(bytes: Array("second-linter".utf8), to: second)
    try MainFixtureFiles.setPermissions(first, posix: 0o755)
    try MainFixtureFiles.setPermissions(second, posix: 0o755)
    defer { try? MainFixtureFiles.remove(root) }

    let process = Source.Engine.Process { _, _, _, _ in
        .init(status: 0, output: "", diagnostics: "")
    }
    let acquisition = Institute.Source.Acquisition(process: process)
    let destination = try File.Directory(validating: tools)
    let firstSnapshot = try acquisition.snapshot(
        executable: first,
        name: "swift-linter",
        into: destination
    )
    let secondSnapshot = try acquisition.snapshot(
        executable: second,
        name: "swift-linter",
        into: destination
    )
    let policy = Institute.Source.Policy.current
    let rules = Institute.Source.Profile(policy: policy).rules(for: .institute)
    let firstProfile = policy.profile(
        swiftFormatExecutable: "/tools/swift-format",
        swiftFormatTool: .init("format"),
        swiftFormatConfigurationPath: "/profile/.swift-format",
        swiftLintExecutable: "/tools/swiftlint",
        swiftLintTool: .init("swiftlint"),
        swiftLintConfigurationPath: "/profile/.swiftlint.yml",
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
        swiftLintExecutable: "/tools/swiftlint",
        swiftLintTool: .init("swiftlint"),
        swiftLintConfigurationPath: "/profile/.swiftlint.yml",
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
    let root = MainFixtureFiles.temporaryPath(MainFixtureFiles.uniqueName())
    let format = MainFixtureFiles.join(root, "swift-format")
    let swiftLint = MainFixtureFiles.join(root, "swiftlint")
    let linter = MainFixtureFiles.join(root, "swift-linter-local")
    try MainFixtureFiles.createDirectory(root)
    try MainFixtureFiles.write(bytes: Array("format".utf8), to: format)
    try MainFixtureFiles.write(bytes: Array("swiftlint".utf8), to: swiftLint)
    try MainFixtureFiles.write(bytes: Array("linter".utf8), to: linter)
    defer { try? MainFixtureFiles.remove(root) }
    let workspace = MainFixtureFiles.join(root, "workspace")
    try MainFixtureFiles.createDirectory(workspace)
    let workspaceFile = MainFixtureFiles.join(workspace, "contents.xcworkspacedata")
    try MainFixtureFiles.write(
        bytes: Array("<Workspace version=\"1.0\"></Workspace>\n".utf8),
        to: workspaceFile
    )
    let workspaceDigest = try Institute.Source.Application.digest(file: workspaceFile).hex

    let preparation = Institute.Source.Preparation(
        policyRevision: Institute.Source.Policy.current.revision,
        binding: .workspace(digest: workspaceDigest),
        swiftFormatExecutable: format,
        swiftFormatTool: try Institute.Source.Application.digest(file: format),
        swiftLintExecutable: swiftLint,
        swiftLint: .init(
            origin: .local,
            digest: try Institute.Source.Application.digest(file: swiftLint)
        ),
        linterExecutable: linter,
        linter: .init(
            origin: .local,
            digest: try Institute.Source.Application.digest(file: linter)
        ),
        directory: root,
        profiles: [:],
        verifiedProfiles: []
    )
    try MainFixtureFiles.write(bytes: Array("tampered".utf8), to: linter)
    let cohort = Institute.Source.Workspace.Cohort(
        workspace: workspace,
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
