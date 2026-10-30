import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `path dependency Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`path dependency Tests` {
    static func observation(
        _ source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        Lint.Rule.`path dependency`.observe(Lint.Source.parsed(from: source, file: file), .warning)
    }
}

extension Lint.Rule.`path dependency Tests`.Unit {
    @Test
    func `path dependency in the package dependencies is flagged`() {
        let observation = Lint.Rule.`path dependency Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                dependencies: [
                    .package(url: "https://github.com/swift-atoms/swift-owner.git", branch: "main"),
                    .package(path: "../swift-other"),
                ]
            )
            """
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.hasPrefix("[path dependency] [PACKAGE-PATH-DEPENDENCY]:"))
    }

    @Test
    func `url dependencies are clean`() {
        let observation = Lint.Rule.`path dependency Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                dependencies: [
                    .package(url: "https://github.com/swift-atoms/swift-owner.git", branch: "main"),
                ]
            )
            """
        )
        #expect(observation.findings.isEmpty)
    }
}

extension Lint.Rule.`path dependency Tests`.`Edge Case` {
    @Test
    func `a target path is not a package dependency`() {
        let observation = Lint.Rule.`path dependency Tests`.observation(
            "let target = Target.target(name: \"Fixture\", path: \"Sources/Fixture\")"
        )
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `non-manifest files are inapplicable`() {
        let observation = Lint.Rule.`path dependency Tests`.observation(
            "let dependency = Package.Dependency.package(path: \"../swift-owner\")",
            file: "Sources/Fixture/Fixture.swift"
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }
}

extension Lint.Rule.`path dependency Tests`.Integration {
    @Test
    func `named path dependency in a versioned manifest is flagged`() {
        let observation = Lint.Rule.`path dependency Tests`.observation(
            "let dependency = Package.Dependency.package(name: \"swift-owner\", path: \"../swift-owner\")",
            file: "Package@swift-6.4.swift"
        )
        #expect(observation.findings.count == 1)
    }
}

extension Lint.Rule.`path dependency Tests`.`Edge Case` {
    static let nestedTestManifest = """
        // swift-tools-version: 6.4
        import PackageDescription

        let package = Package(
            name: "testing",
            dependencies: [
                .package(path: ".."),
                .package(url: "https://github.com/pointfreeco/swift-snapshot-testing.git", branch: "main"),
            ],
            targets: [
                .testTarget(name: "Fixture Snapshot Tests", path: "Fixture Snapshot Tests")
            ]
        )
        """

    @Test
    func `the nested test manifest may reach its parent by path`() {
        for file in ["Tests/Package.swift", "/workspace/swift-fixture/Tests/Package.swift"] {
            let observation = Lint.Rule.`path dependency Tests`.observation(
                Self.nestedTestManifest,
                file: file
            )
            #expect(observation.applicability == .applicable, "\(file)")
            #expect(observation.findings.isEmpty, "\(file)")
        }
    }

    @Test
    func `the root manifest may not reach its parent by path`() {
        let observation = Lint.Rule.`path dependency Tests`.observation(Self.nestedTestManifest)
        #expect(observation.findings.count == 1)
    }

    @Test
    func `the nested test manifest may not reach a sibling or a spelled-out parent by path`() {
        for path in ["../", "../..", "../../swift-owner", "../Sources", "."] {
            let observation = Lint.Rule.`path dependency Tests`.observation(
                "let package = Package(name: \"testing\", dependencies: [.package(path: \"\(path)\")])",
                file: "Tests/Package.swift"
            )
            #expect(observation.findings.count == 1, "\(path)")
        }
    }

    @Test
    func `a manifest under another directory named like Tests is not the nested test manifest`() {
        for file in [
            "Tests/Fixture Tests/Package.swift",
            "MyTests/Package.swift",
            "Tests Support/Package.swift",
            "Tests/Package@swift-6.4.swift",
        ] {
            let observation = Lint.Rule.`path dependency Tests`.observation(
                Self.nestedTestManifest,
                file: file
            )
            #expect(observation.findings.count == 1, "\(file)")
        }
    }
}
