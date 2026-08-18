import Build_Coordinator
import File_System
import Foundation
import Package_Manager
import SPM_Standard
import Testing

@testable import Institute_Development
@testable import Institute_Model

extension Institute.Composed.Root {
    @Suite(.serialized)
    struct Integration {}
}

extension Institute.Composed.Root.Integration {
    /// The committed fixture root, located from this file — fixtures
    /// are source, present wherever the tests compile from.
    private static var fixtures: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appending(path: "Fixtures/Composition")
    }

    private static func scratch() throws -> URL {
        let base = FileManager.default.temporaryDirectory
            .resolvingSymlinksInPath()
            .appending(path: "institute-t6-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }

    private static func copy(_ fixture: Swift.String, into base: URL) throws -> URL {
        let destination = base.appending(path: URL(fileURLWithPath: fixture).lastPathComponent)
        try FileManager.default.copyItem(
            at: fixtures.appending(path: fixture),
            to: destination
        )
        return destination
    }

    /// Renders a template manifest, substituting runtime coordinates.
    private static func instantiate(
        _ template: URL,
        substituting substitutions: [Swift.String: Swift.String]
    ) throws {
        var text = try Swift.String(
            decoding: [UInt8](Data(contentsOf: template)),
            as: Swift.UTF8.self
        )
        for (token, value) in substitutions {
            text = text.replacingOccurrences(of: token, with: value)
        }
        try Data(text.utf8).write(
            to: template.deletingLastPathComponent().appending(path: "Package.swift")
        )
    }

    /// Runs `git` for fixture-repository construction only — never a
    /// SwiftPM operation, which goes through ``Build/Coordinator`` or
    /// ``Package/Manager`` exclusively.
    private static func git(_ arguments: [Swift.String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git"] + arguments
        process.currentDirectoryURL = directory
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
    }

    private static func text(_ result: Build.Coordinator.Result) -> Swift.String {
        let out = result.standardOutput.map { Swift.String(decoding: $0, as: Swift.UTF8.self) }
        let err = result.standardError.map { Swift.String(decoding: $0, as: Swift.UTF8.self) }
        return (out ?? "") + (err ?? "")
    }

    @Test
    func `S4 — a root path dependency wins the identity collision against a transitive remote`()
        throws
    {
        let base = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: base) }
        let fixture = try Self.copy("LocalOverride", into: base)

        // The transitive remote: a real git repository at main.
        let remote = fixture.appending(path: "remote/B")
        try Self.git(["init", "-b", "main"], in: remote)
        try Self.git(["add", "."], in: remote)
        try Self.git(
            [
                "-c", "user.name=fixture", "-c", "user.email=fixture@fixture.invalid",
                "commit", "-m", "fixture",
            ],
            in: remote
        )

        try Self.instantiate(
            fixture.appending(path: "A/Package.template.swift"),
            substituting: ["REMOTE_B_URL": "file://\(remote.path)"]
        )
        try Self.instantiate(
            fixture.appending(path: "C/Package.template.swift"),
            substituting: [
                "PATH_A": fixture.appending(path: "A").path,
                "PATH_B_LOCAL": fixture.appending(path: "local-root/B").path,
            ]
        )

        let coordinator = Build.Coordinator()
        let result = try coordinator.run(
            .build,
            at: fixture.appending(path: "C").path,
            fresh: false,
            arguments: [],
            capturingDiagnostics: true
        )

        // The positive control: `C` references `B.localOnly()`, which
        // exists only in the local copy — compiling at all proves the
        // local override won for the transitive consumer too.
        #expect(result.exitCode == 0, Comment(rawValue: Self.text(result)))

        // The resolver's own state record agrees: identity `b`
        // resolved as a filesystem dependency at the local root.
        let resolution = try Package.Manager().resolution(
            at: fixture.appending(path: "C").path
        )
        let b = resolution.dependency(for: .init("b"))
        #expect(b != nil)
        if let b {
            guard case .fileSystem(let path) = b.state else {
                Issue.record("identity b resolved as \(b.state), not fileSystem")
                return
            }
            #expect(path.contains("local-root"))
        }

        // The standing law-2 risk, asserted so a toolchain escalation
        // fails loudly here rather than silently reddening the fleet:
        // SwiftPM's conflicting-identity diagnostic is present today
        // and self-describes as a future error.
        let diagnostics = Self.text(result)
        #expect(diagnostics.contains("Conflicting identity"))
        #expect(diagnostics.contains("escalated to an error"))
    }

    @Test
    func `two paths with the same evaluated identity fail`() throws {
        let base = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: base) }
        let fixture = try Self.copy("IdentityCollision", into: base)

        try Self.instantiate(
            fixture.appending(path: "Root/Package.template.swift"),
            substituting: [
                "PATH_X_B": fixture.appending(path: "X/B").path,
                "PATH_Y_B": fixture.appending(path: "Y/B").path,
            ]
        )

        let result = try Build.Coordinator().run(
            .build,
            at: fixture.appending(path: "Root").path,
            fresh: false,
            arguments: [],
            capturingDiagnostics: true
        )
        #expect(result.exitCode != 0)
        #expect(Self.text(result).lowercased().contains("identity"))
    }

    @Test
    func `inventory-directory spelling divergence is reported, not silently accepted`() throws {
        let base = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: base) }

        // A real hierarchy: root/swift-primitives/<reference>, where the
        // materialized manifest's evaluated name diverges from the
        // inventory reference. Evaluation is the real Package.Manager.
        let checkout = base.appending(path: "checkout")
        let root = base.appending(path: "root/swift-primitives")
        try FileManager.default.createDirectory(at: checkout, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: Self.fixtures.appending(path: "IdentityDivergence/swift-divergent-primitives"),
            to: root.appending(path: "swift-divergent-primitives")
        )

        let checkoutDirectory = try File.Directory(validating: checkout.path)
        try Institute.Hierarchy.Registry.register(
            id: try Institute.Hierarchy.ID("main"),
            locator: try File.Directory(validating: base.appending(path: "root").path),
            ownership: .adopted,
            at: checkoutDirectory
        )

        let map = Institute.Composition.SourceMap(
            defaultHierarchy: try Institute.Hierarchy.ID("main")
        )
        do {
            _ = try map.normalized(
                scope: .seeds(["swift-divergent-primitives"]),
                roster: [
                    .init(
                        name: "swift-divergent-primitives",
                        url: "https://github.com/swift-primitives/swift-divergent-primitives.git",
                        organization: "swift-primitives",
                        layer: .primitives
                    )
                ],
                at: checkoutDirectory
            )
            Issue.record("divergence was silently accepted")
        } catch {
            guard case .identityDivergence(let reference, let evaluated) = error else {
                Issue.record("unexpected error \(error)")
                return
            }
            #expect(reference == "swift-divergent-primitives")
            #expect(evaluated == "swift-divergent-spelling")
        }
    }

    @Test
    func `S5 — one generated graph references packages under two registered roots`() throws {
        let base = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: base) }

        // Two physically unrelated roots.
        let one = base.appending(path: "alpha/materialized")
        let two = base.appending(path: "beta/elsewhere")
        try FileManager.default.createDirectory(at: one, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: two, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: Self.fixtures.appending(path: "MixedRoots/root-one/B"),
            to: one.appending(path: "B")
        )
        try FileManager.default.copyItem(
            at: Self.fixtures.appending(path: "MixedRoots/root-two/D"),
            to: two.appending(path: "D")
        )
        let consumer = base.appending(path: "consumer/E")
        try FileManager.default.createDirectory(at: consumer, withIntermediateDirectories: true)
        try FileManager.default.copyItem(
            at: Self.fixtures.appending(path: "MixedRoots/E/Sources"),
            to: consumer.appending(path: "Sources")
        )
        try FileManager.default.copyItem(
            at: Self.fixtures.appending(path: "MixedRoots/E/Package.template.swift"),
            to: consumer.appending(path: "Package.template.swift")
        )
        try Self.instantiate(
            consumer.appending(path: "Package.template.swift"),
            substituting: [
                "PATH_B": one.appending(path: "B").path,
                "PATH_D": two.appending(path: "D").path,
            ]
        )

        let result = try Build.Coordinator().run(
            .build,
            at: consumer.path,
            fresh: false,
            arguments: [],
            capturingDiagnostics: true
        )
        #expect(result.exitCode == 0, Comment(rawValue: Self.text(result)))
        #expect(!Self.text(result).contains("Conflicting identity"))
    }

    @Test
    func `library-less, duplicate product names, and empty population laws hold`() throws {
        let base = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: base) }
        let fixture = try Self.copy("LibraryLess", into: base)

        // Two identities exposing one product name, plus an
        // executable-only package: the plan keeps the library-less
        // package visible as a path dependency with a typed reason,
        // qualifies the colliding product names by identity, and the
        // whole graph builds.
        let plan = try Institute.Composition.BuildPlan(
            seeds: [],
            packages: [
                .init(
                    identity: "lib",
                    reference: fixture.appending(path: "Lib").path,
                    libraryProducts: ["Shared Name"],
                    buildableTargetCount: 1
                ),
                .init(
                    identity: "second",
                    reference: fixture.appending(path: "Second").path,
                    libraryProducts: ["Shared Name"],
                    buildableTargetCount: 1
                ),
                .init(
                    identity: "tool",
                    reference: fixture.appending(path: "Tool").path,
                    libraryProducts: [],
                    buildableTargetCount: 1
                ),
            ]
        )
        #expect(plan.exclusions.map(\.identity) == ["tool"])
        #expect(plan.pathDependencyCount == 3)
        #expect(plan.expectedTargetCount == 2)

        let workspace = Institute.Composition.Workspace.keyed(
            "t6-libraryless",
            under: try File.Directory(validating: base.path),
            anchor: try File.Directory(validating: base.path)
        )
        try Institute.Composed.Root.write(plan, swift: "6.3.3", in: workspace)

        let result = try Build.Coordinator().run(
            .build,
            at: Institute.Composed.Root.directory(in: workspace).description,
            fresh: false,
            arguments: [],
            capturingDiagnostics: true
        )
        #expect(result.exitCode == 0, Comment(rawValue: Self.text(result)))

        // An empty or non-enumerated population is a typed failure,
        // never a rendered green nothing.
        #expect(throws: Institute.Composition.BuildPlan.Error.self) {
            _ = try Institute.Composition.BuildPlan(seeds: [], packages: [])
        }
    }

    @Test
    func `a physical path escape fails`() throws {
        let base = try Self.scratch()
        defer { try? FileManager.default.removeItem(at: base) }

        let root = base.appending(path: "root")
        let outside = base.appending(path: "outside/swift-escapee")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(
            at: root.appending(path: "swift-primitives"),
            withDestinationURL: base.appending(path: "outside")
        )

        #expect(throws: Institute.Error.self) {
            try Institute.Root.preflight(
                File.Directory(
                    try File.Path(root.appending(path: "swift-primitives/swift-escapee").path)
                ),
                under: File.Directory(try File.Path(root.path))
            )
        }
    }
}
