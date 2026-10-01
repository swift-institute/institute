import Institute_Build_Coordinator
import File_System
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
    private static var fixtures: Swift.String {
        DevelopmentFixtureFiles.sibling(of: #filePath, "Fixtures/Composition")
    }

    private static func scratch() throws -> Swift.String {
        let base = DevelopmentFixtureFiles.temporaryPath(
            resolvingSymlinks: true,
            "institute-t6-\(DevelopmentFixtureFiles.uniqueName())"
        )
        try DevelopmentFixtureFiles.createDirectory(base)
        return base
    }

    private static func copy(_ fixture: Swift.String, into base: Swift.String) throws -> Swift.String {
        let destination = DevelopmentFixtureFiles.join(
            base,
            DevelopmentFixtureFiles.lastComponent(of: fixture)
        )
        try DevelopmentFixtureFiles.copy(
            DevelopmentFixtureFiles.join(fixtures, fixture),
            to: destination
        )
        return destination
    }

    /// Renders a template manifest, substituting runtime coordinates.
    private static func instantiate(
        _ template: Swift.String,
        substituting substitutions: [Swift.String: Swift.String]
    ) throws {
        var text = Swift.String(
            decoding: try DevelopmentFixtureFiles.readBytes(template),
            as: Swift.UTF8.self
        )
        for (token, value) in substitutions {
            text = DevelopmentFixtureFiles.replacingAll(token, with: value, in: text)
        }
        try DevelopmentFixtureFiles.write(
            bytes: Array(text.utf8),
            to: DevelopmentFixtureFiles.sibling(of: template, "Package.swift")
        )
    }

    /// Runs `git` for fixture-repository construction only — never a
    /// SwiftPM operation, which goes through ``Build/Coordinator`` or
    /// ``Package/Manager`` exclusively.
    private static func git(_ arguments: [Swift.String], in directory: Swift.String) throws {
        try DevelopmentFixtureFiles.git(arguments, in: directory)
    }

    private static func text(_ result: Institute.Build.Coordinator.Result) -> Swift.String {
        let out = result.standardOutput.map { Swift.String(decoding: $0, as: Swift.UTF8.self) }
        let err = result.standardError.map { Swift.String(decoding: $0, as: Swift.UTF8.self) }
        return (out ?? "") + (err ?? "")
    }

    @Test
    func `S4 — a root path dependency wins the identity collision against a transitive remote`()
        throws
    {
        let base = try Self.scratch()
        defer { try? DevelopmentFixtureFiles.remove(base) }
        let fixture = try Self.copy("LocalOverride", into: base)

        // The transitive remote: a real git repository at main.
        let remote = DevelopmentFixtureFiles.join(fixture, "remote/B")
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
            DevelopmentFixtureFiles.join(fixture, "A/Package.template.swift"),
            substituting: ["REMOTE_B_URL": "file://\(remote)"]
        )
        try Self.instantiate(
            DevelopmentFixtureFiles.join(fixture, "C/Package.template.swift"),
            substituting: [
                "PATH_A": DevelopmentFixtureFiles.join(fixture, "A"),
                "PATH_B_LOCAL": DevelopmentFixtureFiles.join(fixture, "local-root/B"),
            ]
        )

        let coordinator = Institute.Build.Coordinator()
        let result = try coordinator.run(
            .build,
            at: DevelopmentFixtureFiles.join(fixture, "C"),
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
            at: DevelopmentFixtureFiles.join(fixture, "C")
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
        defer { try? DevelopmentFixtureFiles.remove(base) }
        let fixture = try Self.copy("IdentityCollision", into: base)

        try Self.instantiate(
            DevelopmentFixtureFiles.join(fixture, "Root/Package.template.swift"),
            substituting: [
                "PATH_X_B": DevelopmentFixtureFiles.join(fixture, "X/B"),
                "PATH_Y_B": DevelopmentFixtureFiles.join(fixture, "Y/B"),
            ]
        )

        let result = try Institute.Build.Coordinator().run(
            .build,
            at: DevelopmentFixtureFiles.join(fixture, "Root"),
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
        defer { try? DevelopmentFixtureFiles.remove(base) }

        // A real hierarchy: root/swift-primitives/<reference>, where the
        // materialized manifest's evaluated name diverges from the
        // inventory reference. Evaluation is the real Package.Manager.
        let checkout = DevelopmentFixtureFiles.join(base, "checkout")
        let root = DevelopmentFixtureFiles.join(base, "root/swift-primitives")
        try DevelopmentFixtureFiles.createDirectory(checkout)
        try DevelopmentFixtureFiles.createDirectory(root)
        try DevelopmentFixtureFiles.copy(DevelopmentFixtureFiles.join(Self.fixtures, "IdentityDivergence/swift-divergent-primitives"), to: DevelopmentFixtureFiles.join(root, "swift-divergent-primitives")
        )

        let checkoutDirectory = try File.Directory(validating: checkout)
        try Institute.Hierarchy.Registry.register(
            id: try Institute.Hierarchy.ID("main"),
            locator: try File.Directory(validating: DevelopmentFixtureFiles.join(base, "root")),
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
        defer { try? DevelopmentFixtureFiles.remove(base) }

        // Two physically unrelated roots.
        let one = DevelopmentFixtureFiles.join(base, "alpha/materialized")
        let two = DevelopmentFixtureFiles.join(base, "beta/elsewhere")
        try DevelopmentFixtureFiles.createDirectory(one)
        try DevelopmentFixtureFiles.createDirectory(two)
        try DevelopmentFixtureFiles.copy(DevelopmentFixtureFiles.join(Self.fixtures, "MixedRoots/root-one/B"), to: DevelopmentFixtureFiles.join(one, "B")
        )
        try DevelopmentFixtureFiles.copy(DevelopmentFixtureFiles.join(Self.fixtures, "MixedRoots/root-two/D"), to: DevelopmentFixtureFiles.join(two, "D")
        )
        let consumer = DevelopmentFixtureFiles.join(base, "consumer/E")
        try DevelopmentFixtureFiles.createDirectory(consumer)
        try DevelopmentFixtureFiles.copy(DevelopmentFixtureFiles.join(Self.fixtures, "MixedRoots/E/Sources"), to: DevelopmentFixtureFiles.join(consumer, "Sources")
        )
        try DevelopmentFixtureFiles.copy(DevelopmentFixtureFiles.join(Self.fixtures, "MixedRoots/E/Package.template.swift"), to: DevelopmentFixtureFiles.join(consumer, "Package.template.swift")
        )
        try Self.instantiate(
            DevelopmentFixtureFiles.join(consumer, "Package.template.swift"),
            substituting: [
                "PATH_B": DevelopmentFixtureFiles.join(one, "B"),
                "PATH_D": DevelopmentFixtureFiles.join(two, "D"),
            ]
        )

        let result = try Institute.Build.Coordinator().run(
            .build,
            at: consumer,
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
        defer { try? DevelopmentFixtureFiles.remove(base) }
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
                    reference: DevelopmentFixtureFiles.join(fixture, "Lib"),
                    libraryProducts: ["Shared Name"],
                    buildableTargetCount: 1
                ),
                .init(
                    identity: "second",
                    reference: DevelopmentFixtureFiles.join(fixture, "Second"),
                    libraryProducts: ["Shared Name"],
                    buildableTargetCount: 1
                ),
                .init(
                    identity: "tool",
                    reference: DevelopmentFixtureFiles.join(fixture, "Tool"),
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
            under: try File.Directory(validating: base),
            anchor: try File.Directory(validating: base)
        )
        try Institute.Composed.Root.write(plan, swift: "6.3.3", in: workspace)

        let result = try Institute.Build.Coordinator().run(
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
        defer { try? DevelopmentFixtureFiles.remove(base) }

        let root = DevelopmentFixtureFiles.join(base, "root")
        let outside = DevelopmentFixtureFiles.join(base, "outside/swift-escapee")
        try DevelopmentFixtureFiles.createDirectory(root)
        try DevelopmentFixtureFiles.createDirectory(outside)
        try DevelopmentFixtureFiles.createSymbolicLink(DevelopmentFixtureFiles.join(root, "swift-primitives"), to: DevelopmentFixtureFiles.join(base, "outside")
        )

        #expect(throws: Institute.Error.self) {
            try Institute.Root.preflight(
                File.Directory(
                    try File.Path(DevelopmentFixtureFiles.join(root, "swift-primitives/swift-escapee"))
                ),
                under: File.Directory(try File.Path(root))
            )
        }
    }
}
