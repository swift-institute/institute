import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `default trait Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`default trait Tests` {
    static func observation(
        _ source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        Lint.Rule.`default trait`.observe(Lint.Source.parsed(from: source, file: file), .warning)
    }
}

extension Lint.Rule.`default trait Tests`.Unit {
    @Test
    func `a default trait declaration is flagged`() {
        let observation = Lint.Rule.`default trait Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                traits: [
                    .trait(name: "Parser"),
                    .default(enabledTraits: ["Parser"]),
                ]
            )
            """
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.hasPrefix("[default trait] [PACKAGE-DEFAULT-TRAIT]:"))
    }

    @Test
    func `traits without a default are clean`() {
        let observation = Lint.Rule.`default trait Tests`.observation(
            "let package = Package(name: \"Fixture\", traits: [.trait(name: \"Parser\")])"
        )
        #expect(observation.findings.isEmpty)
    }
}

extension Lint.Rule.`default trait Tests`.`Edge Case` {
    @Test
    func `requesting a dependency's defaults is not a declaration`() {
        let observation = Lint.Rule.`default trait Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                dependencies: [
                    .package(url: "https://github.com/swift-atoms/swift-manifest.git", branch: "main", traits: [.defaults, "Parser"]),
                ]
            )
            """
        )
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `non-manifest files are inapplicable`() {
        let observation = Lint.Rule.`default trait Tests`.observation(
            "let trait = Trait.default(enabledTraits: [\"Parser\"])",
            file: "Sources/Fixture/Fixture.swift"
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }
}

extension Lint.Rule.`default trait Tests`.Integration {
    @Test
    func `a default trait in a versioned manifest is flagged`() {
        let observation = Lint.Rule.`default trait Tests`.observation(
            "let traits: Set<Trait> = [.default(enabledTraits: [])]",
            file: "Package@swift-6.4.swift"
        )
        #expect(observation.findings.count == 1)
    }
}
