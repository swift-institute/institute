import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `platform floor Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`platform floor Tests` {
    static func observation(
        _ source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        Lint.Rule.`platform floor`.observe(Lint.Source.parsed(from: source, file: file), .warning)
    }
}

extension Lint.Rule.`platform floor Tests`.Unit {
    @Test
    func `five platforms at 27 are clean`() {
        let observation = Lint.Rule.`platform floor Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                platforms: [
                    .macOS(.v27),
                    .iOS(.v27),
                    .tvOS(.v27),
                    .watchOS(.v27),
                    .visionOS(.v27),
                ]
            )
            """
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `each missing or lower platform is flagged`() {
        let observation = Lint.Rule.`platform floor Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                platforms: [.macOS(.v26), .iOS(.v27)]
            )
            """
        )
        #expect(observation.findings.count == 4)
        #expect(observation.findings[0].message.hasPrefix("[platform floor] [PACKAGE-PLATFORM-FLOOR]:"))
        #expect(observation.findings[0].message.contains("`.macOS` must use `.v27`, not `.v26`"))
    }
}

extension Lint.Rule.`platform floor Tests`.`Edge Case` {
    @Test
    func `a package without platforms is flagged once`() {
        let observation = Lint.Rule.`platform floor Tests`.observation(
            "let package = Package(name: \"Fixture\")"
        )
        #expect(observation.findings.count == 1)
    }

    @Test
    func `computed platforms are unmeasured`() {
        let observation = Lint.Rule.`platform floor Tests`.observation(
            "let platforms: [SupportedPlatform] = []\nlet package = Package(name: \"Fixture\", platforms: platforms)"
        )
        #expect(observation.coverage != .measured)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `non-manifest files are inapplicable`() {
        let observation = Lint.Rule.`platform floor Tests`.observation(
            "let package = Package(name: \"Fixture\")",
            file: "Sources/Fixture/Fixture.swift"
        )
        #expect(observation.applicability == .inapplicable)
    }
}

extension Lint.Rule.`platform floor Tests`.Integration {
    @Test
    func `a versioned manifest is checked`() {
        let observation = Lint.Rule.`platform floor Tests`.observation(
            "let package = Package(name: \"Fixture\", platforms: [.macOS(.v27), .iOS(.v27), .tvOS(.v27), .watchOS(.v27)])",
            file: "Package@swift-6.4.swift"
        )
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("visionOS"))
    }
}

extension Lint.Rule.`platform floor Tests`.Integration {
    static func repaired(_ source: Swift::String) -> Swift::String? {
        let proposal = Lint.Rule.`platform floor`.repair(Lint.Source.parsed(from: source, file: "Package.swift"))
        guard case .edits(let edits) = proposal, case .rewrite(_, let contents) = edits.first else {
            return nil
        }
        return contents
    }

    static let canonical = """
        [
                .macOS(.v27),
                .iOS(.v27),
                .tvOS(.v27),
                .watchOS(.v27),
                .visionOS(.v27),
            ]
        """

    @Test
    func `repair rewrites a lower platform list`() {
        let repaired = Self.repaired(
            "let package = Package(\n    name: \"Fixture\",\n    platforms: [.macOS(.v26)],\n    products: []\n)"
        )
        #expect(
            repaired
                == "let package = Package(\n    name: \"Fixture\",\n    platforms: \(Self.canonical),\n    products: []\n)"
        )
        #expect(repaired.map { Lint.Rule.`platform floor Tests`.observation($0).findings.isEmpty } == true)
    }

    @Test
    func `repair inserts platforms after the name`() {
        let repaired = Self.repaired("let package = Package(\n    name: \"Fixture\",\n    products: []\n)")
        #expect(
            repaired
                == "let package = Package(\n    name: \"Fixture\",\n    platforms: \(Self.canonical),\n    products: []\n)"
        )
    }

    @Test
    func `repair leaves a floor-compliant manifest unchanged`() {
        let proposal = Lint.Rule.`platform floor`.repair(
            Lint.Source.parsed(
                from: "let package = Package(name: \"Fixture\", platforms: [.macOS(.v27), .iOS(.v27), .tvOS(.v27), .watchOS(.v27), .visionOS(.v27)])",
                file: "Package.swift"
            )
        )
        #expect(proposal == .unchanged)
    }
}

extension Lint.Rule.`platform floor Tests`.`Edge Case` {
    @Test
    func `repair leaves non-manifest files unchanged`() {
        let proposal = Lint.Rule.`platform floor`.repair(
            Lint.Source.parsed(from: "let package = Package(name: \"Fixture\")", file: "Sources/Fixture/Fixture.swift")
        )
        #expect(proposal == .unchanged)
    }
}
