import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `test target naming Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`test target naming Tests` {
    static func observation(
        _ source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        Lint.Rule.`test target naming`.observe(Lint.Source.parsed(from: source, file: file), .warning)
    }
}

extension Lint.Rule.`test target naming Tests`.Unit {
    @Test
    func `one test target per target named after it is clean`() {
        let observation = Lint.Rule.`test target naming Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                targets: [
                    .target(name: "Fixture Core"),
                    .executableTarget(name: "Fixture CLI"),
                    .testTarget(name: "Fixture Core Tests", dependencies: [.target(name: "Fixture Core")]),
                    .testTarget(name: "Fixture CLI Tests"),
                ]
            )
            """
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `a test target without the spaced suffix is flagged`() {
        let observation = Lint.Rule.`test target naming Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                targets: [
                    .target(name: "FixtureCore"),
                    .testTarget(name: "FixtureCoreTests"),
                ]
            )
            """
        )
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.hasPrefix("[test target naming] [PACKAGE-TEST-TARGET-NAMING]:"))
    }

    @Test
    func `a package-wide test target is flagged`() {
        let observation = Lint.Rule.`test target naming Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                targets: [
                    .target(name: "Fixture Core"),
                    .target(name: "Fixture Parser"),
                    .testTarget(name: "Fixture Tests"),
                ]
            )
            """
        )
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("names no target"))
    }
}

extension Lint.Rule.`test target naming Tests`.`Edge Case` {
    @Test
    func `a duplicated test target is flagged once`() {
        let observation = Lint.Rule.`test target naming Tests`.observation(
            """
            let package = Package(
                name: "Fixture",
                targets: [
                    .target(name: "Fixture Core"),
                    .testTarget(name: "Fixture Core Tests"),
                    .testTarget(name: "Fixture Core Tests"),
                ]
            )
            """
        )
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("declared twice"))
    }

    @Test
    func `a computed test target name is unmeasured`() {
        let observation = Lint.Rule.`test target naming Tests`.observation(
            """
            let name = "Fixture Core"
            let package = Package(
                name: "Fixture",
                targets: [
                    .target(name: "Fixture Core"),
                    .testTarget(name: name + " Tests"),
                ]
            )
            """
        )
        #expect(observation.coverage != .measured)
    }

    @Test
    func `a test target named through a String accessor is unmeasured, not resolved`() {
        let observation = Lint.Rule.`test target naming Tests`.observation(
            """
            extension String {
                static let products: Self = "Products"
                var tests: Self { self + " Tests" }
            }
            let package = Package(
                name: "swift-products",
                targets: [
                    .target(name: .products),
                    .testTarget(name: .products.tests),
                ]
            )
            """
        )
        #expect(observation.coverage == .unmeasured(.unsupportedSourceShape("target name is not a string literal")))
    }

    @Test
    func `the literal spelling of the same manifest is measured and clean`() {
        let observation = Lint.Rule.`test target naming Tests`.observation(
            """
            let package = Package(
                name: "swift-products",
                targets: [
                    .target(name: "Products"),
                    .target(name: "Products Live"),
                    .testTarget(name: "Products Tests"),
                ]
            )
            """
        )
        #expect(observation.coverage == .measured)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `non-manifest files are inapplicable`() {
        let observation = Lint.Rule.`test target naming Tests`.observation(
            "let target = Target.testTarget(name: \"FixtureTests\")",
            file: "Sources/Fixture/Fixture.swift"
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }
}

extension Lint.Rule.`test target naming Tests`.Integration {
    @Test
    func `a versioned manifest is checked`() {
        let observation = Lint.Rule.`test target naming Tests`.observation(
            "let targets: [Target] = [.target(name: \"Fixture\"), .testTarget(name: \"FixtureTests\")]",
            file: "Package@swift-6.4.swift"
        )
        #expect(observation.findings.count == 1)
    }
}
