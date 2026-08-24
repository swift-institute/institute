import Institute_Model
import Institute_Source_Policy
import JSON
import Source_Profile
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
        linterTool: .init("linter-tool"),
        directory: "/artifacts/.source",
        profiles: ["institute": .init("profile-digest")],
        verifiedProfiles: ["institute"]
    )

    let decoded = try Institute.Source.Preparation(json: preparation.json)

    #expect(decoded.policyRevision == preparation.policyRevision)
    #expect(decoded.workspaceDigest == preparation.workspaceDigest)
    #expect(decoded.swiftFormatExecutable == preparation.swiftFormatExecutable)
    #expect(decoded.swiftFormatTool == preparation.swiftFormatTool)
    #expect(decoded.linterExecutable == preparation.linterExecutable)
    #expect(decoded.linterTool == preparation.linterTool)
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
        linterTool: .init("linter-tool"),
        directory: "/artifacts/.source",
        profiles: [:],
        verifiedProfiles: []
    )
    var object = try #require(preparation.json.dictionary)
    object["verifiedProfiles"] = nil

    #expect(throws: JSON.Error.self) {
        _ = try Institute.Source.Preparation(
            json: .object(
                object.keys.sorted().compactMap { key in
                    object[key].map { (key, $0) }
                }
            )
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
