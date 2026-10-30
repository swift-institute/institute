import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `package policy revision 1 Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`package policy revision 1 Tests` {
    static let clean = """
        // swift-tools-version: 6.4

        import PackageDescription

        let package = Package(
            name: "fixture",
            platforms: [.macOS(.v27), .iOS(.v27)],
            targets: [.target(name: "Fixture")],
            swiftLanguageModes: [.v6]
        )

        for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
            target.swiftSettings = (target.swiftSettings ?? []) + [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
                .enableExperimentalFeature("Lifetimes"),
                .enableUpcomingFeature("InferIsolatedConformances"),
            ]
        }
        """

    static func observation(
        _ source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`package policy revision 1`.observe(parsed, .error)
    }
}

extension Lint.Rule.`package policy revision 1 Tests`.Unit {
    @Test
    func `complete executable revision is clean`() {
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(
            Lint.Rule.`package policy revision 1 Tests`.clean
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `each missing target setting is an exact finding`() {
        let dirty = Lint.Rule.`package policy revision 1 Tests`.clean.replacing(
            ".enableUpcomingFeature(\"InferIsolatedConformances\"),",
            with: ""
        )
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(dirty)
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("InferIsolatedConformances"))
    }

    @Test
    func `concrete language and platform drift are findings`() {
        let dirty = Lint.Rule.`package policy revision 1 Tests`.clean
            .replacing(".macOS(.v27)", with: ".macOS(.v26)")
            .replacing("swiftLanguageModes: [.v6]", with: "swiftLanguageModes: [.v5]")
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(dirty)
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 2)
    }

    @Test
    func `settings loop that does not exclude macro targets is measured`() {
        let source = Lint.Rule.`package policy revision 1 Tests`.clean.replacing(
            "![.system, .binary, .plugin, .macro]",
            with: "![.system, .binary, .plugin]"
        )
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(source)
        #expect(observation.coverage == .measured)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `settings loop over every target is measured`() {
        let source = Lint.Rule.`package policy revision 1 Tests`.clean.replacing(
            " where ![.system, .binary, .plugin, .macro].contains(target.type)",
            with: ""
        )
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(source)
        #expect(observation.coverage == .measured)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `settings declared in a local list inside the loop are read`() {
        let source = Lint.Rule.`package policy revision 1 Tests`.clean
            .replacing(
                "    target.swiftSettings = (target.swiftSettings ?? []) + [",
                with: "    let ecosystem: [SwiftSetting] = ["
            )
            .replacing("    ]\n}", with: "    ]\n    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem\n}")
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(source)
        #expect(observation.coverage == .measured)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `manifest that applies no target settings reports every setting`() {
        let source = """
            // swift-tools-version: 6.4
            import PackageDescription
            let package = Package(
                name: "fixture",
                targets: [.target(name: "Fixture"), .testTarget(name: "Fixture Tests")],
                swiftLanguageModes: [.v6]
            )
            """
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(source)
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 7)
    }
}

extension Lint.Rule.`package policy revision 1 Tests`.`Edge Case` {
    @Test
    func `computed language mode is unmeasured`() {
        let source = Lint.Rule.`package policy revision 1 Tests`.clean.replacing(
            "swiftLanguageModes: [.v6]",
            with: "swiftLanguageModes: modes"
        )
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(source)
        #expect(observation.findings.isEmpty)
        #expect(
            observation.coverage
                == .unmeasured(.unsupportedSourceShape("computed or noncanonical swiftLanguageModes"))
        )
    }

    @Test
    func `unrecognized target-setting application is unmeasured`() {
        let marker =
            "for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type)"
        let source = Lint.Rule.`package policy revision 1 Tests`.clean.replacing(
            marker,
            with: "for target in ordinaryTargets(package)"
        )
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(source)
        guard case .unmeasured = observation.coverage else {
            Issue.record("computed target scope was accepted as measured")
            return
        }
    }

    @Test
    func `settings loop that excludes an ordinary target type is unmeasured`() {
        let source = Lint.Rule.`package policy revision 1 Tests`.clean.replacing(
            "![.system, .binary, .plugin, .macro]",
            with: "![.system, .binary, .plugin, .macro, .test]"
        )
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(source)
        guard case .unmeasured = observation.coverage else {
            Issue.record("a loop that skips test targets was accepted as applying settings to them")
            return
        }
    }

    @Test
    func `conditional settings assignment in the loop is unmeasured`() {
        let source = Lint.Rule.`package policy revision 1 Tests`.clean
            .replacing(
                "    target.swiftSettings = (target.swiftSettings ?? []) + [",
                with: "    if target.name == \"Fixture\" { target.swiftSettings = (target.swiftSettings ?? []) + ["
            )
            .replacing("    ]\n}", with: "    ] }\n}")
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(source)
        guard case .unmeasured = observation.coverage else {
            Issue.record("settings applied to one target were accepted as applied to all")
            return
        }
    }

    @Test
    func `per-target settings without a loop are unmeasured`() {
        let source = """
            // swift-tools-version: 6.4
            import PackageDescription
            let package = Package(
                name: "fixture",
                targets: [.target(name: "Fixture", swiftSettings: settings)],
                swiftLanguageModes: [.v6]
            )
            """
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(source)
        guard case .unmeasured = observation.coverage else {
            Issue.record("computed per-target settings were accepted as measured")
            return
        }
    }

    @Test
    func `L1 macro target is rejected`() {
        let source = """
            // swift-tools-version: 6.4
            import PackageDescription
            let package = Package(
                name: "macro-fixture",
                targets: [.macro(name: "Fixture Macro")],
                swiftLanguageModes: [.v6]
            )
            """
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(
            source,
            file: "/workspace/swift-molecules/macro-fixture/Package.swift"
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("must not declare a macro"))
    }

    @Test
    func `L1 macro target in an atoms package is rejected`() {
        let source = """
            // swift-tools-version: 6.4
            import PackageDescription
            let package = Package(
                name: "macro-fixture",
                targets: [.macro(name: "Fixture Macro")],
                swiftLanguageModes: [.v6]
            )
            """
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(
            source,
            file: "/workspace/swift-atoms/macro-fixture/Package.swift"
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("must not declare a macro"))
    }
}

extension Lint.Rule.`package policy revision 1 Tests`.Integration {
    @Test
    func `dirty to clean control and typed repair refusal`() {
        let dirty = Lint.Rule.`package policy revision 1 Tests`.clean.replacing(
            "// swift-tools-version: 6.4",
            with: "// swift-tools-version: 6.3"
        )
        #expect(
            Lint.Rule.`package policy revision 1 Tests`.observation(dirty).findings.count == 1
        )
        #expect(
            Lint.Rule.`package policy revision 1 Tests`.observation(
                Lint.Rule.`package policy revision 1 Tests`.clean
            ).findings.isEmpty
        )

        let parsed = Lint.Source.parsed(from: dirty, file: "Package.swift")
        #expect(
            Lint.Rule.`package policy revision 1`.repair(parsed)
                == .refused(.repairUnavailable)
        )
    }

    @Test
    func `ordinary source is not applicable`() {
        let observation = Lint.Rule.`package policy revision 1 Tests`.observation(
            "struct Package {}",
            file: "Sources/Package.swift"
        )
        #expect(!observation.applicability.isApplicable)
        #expect(observation.coverage == .measured)
    }
}

extension Lint.Rule.`package policy revision 1 Tests`.`Edge Case` {
    @Test func `the root manifest is a manifest whatever it contains`() {
        #expect(manifestIsPackageManifest("/repo/Package.swift", path: "Package.swift", text: "// swift-tools-version: 6.4\n"))
    }

    @Test func `a nested Package.swift that only names a tools version is not a manifest`() {
        #expect(
            !manifestIsPackageManifest(
                "/repo/Tests/Fixtures/plain/Package.swift",
                path: "Tests/Fixtures/plain/Package.swift",
                text: "// swift-tools-version: 6.3\n"
            )
        )
    }

    @Test func `a nested real manifest is a manifest`() {
        #expect(
            manifestIsPackageManifest(
                "/repo/Tests/Package.swift",
                path: "Tests/Package.swift",
                text: "// swift-tools-version: 6.4\nimport PackageDescription\nlet package = Package(name: \"testing\")\n"
            )
        )
    }
}
