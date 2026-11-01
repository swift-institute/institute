import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `declarative manifest Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`declarative manifest Tests` {
    static func observation(
        _ source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        Lint.Rule.`declarative manifest`.observe(Lint.Source.parsed(from: source, file: file), .warning)
    }

    static let package = """
        // swift-tools-version: 6.4
        import PackageDescription

        let shared: [SwiftSetting] = [.strictMemorySafety()]

        let package = Package(
            name: "Fixture",
            products: [.library(name: "Core", targets: ["Core"])],
            targets: [.target(name: "Core", swiftSettings: shared)]
        )

        """
}

extension Lint.Rule.`declarative manifest Tests`.Unit {
    @Test
    func `a literal manifest is clean`() {
        #expect(Lint.Rule.`declarative manifest Tests`.observation(Lint.Rule.`declarative manifest Tests`.package).findings.isEmpty)
    }

    @Test
    func `products mapped from their names are flagged at the closure`() {
        let source = Lint.Rule.`declarative manifest Tests`.package + """
            package.products += [
                "Core WebKit",
            ].map { .library(name: $0, targets: [$0]) }

            """
        let findings = Lint.Rule.`declarative manifest Tests`.observation(source).findings
        #expect(findings.count == 1)
        #expect(findings.first?.message.hasPrefix("[declarative manifest]: a closure") == true)
    }

    @Test
    func `a top-level loop other than the settings tail is flagged`() {
        let source = Lint.Rule.`declarative manifest Tests`.package + """
            for target in extraTargets {
                target.swiftSettings = shared
            }

            """
        #expect(Lint.Rule.`declarative manifest Tests`.observation(source).findings.count == 1)
    }

    @Test
    func `a var is flagged`() {
        let source = "import PackageDescription\n\nvar names = [\"Core\"]\n\nlet package = Package(name: \"Fixture\")\n"
        #expect(Lint.Rule.`declarative manifest Tests`.observation(source).findings.count == 1)
    }

    @Test
    func `top-level control flow is flagged`() {
        let source = "import PackageDescription\n\nlet package = Package(name: \"Fixture\")\n\nif true {\n    package.targets = []\n}\n"
        #expect(Lint.Rule.`declarative manifest Tests`.observation(source).findings.count == 1)
    }
}

extension Lint.Rule.`declarative manifest Tests`.`Edge Case` {
    @Test
    func `the canonical settings tail is exempt`() {
        let source = Lint.Rule.`declarative manifest Tests`.package + manifestCanonicalSettingsTail
        #expect(Lint.Rule.`declarative manifest Tests`.observation(source).findings.isEmpty)
    }

    @Test
    func `appends and #if blocks the parser reads are clean`() {
        let source = Lint.Rule.`declarative manifest Tests`.package + """
            #if canImport(Darwin)
            package.products += [.library(name: "Core WebKit", targets: ["Core WebKit"])]
            package.targets.append(.target(name: "Core WebKit"))
            #endif

            """
        #expect(Lint.Rule.`declarative manifest Tests`.observation(source).findings.isEmpty)
    }

    @Test
    func `a closure inside an #if block is flagged`() {
        let source = Lint.Rule.`declarative manifest Tests`.package + """
            #if os(macOS)
            package.targets += ["A"].map { .target(name: $0) }
            #endif

            """
        #expect(Lint.Rule.`declarative manifest Tests`.observation(source).findings.count == 1)
    }

    @Test
    func `a file that is not a manifest is not applicable`() {
        let observation = Lint.Rule.`declarative manifest Tests`.observation(
            "let names = [\"A\"].map { $0 }",
            file: "Sources/Core/Names.swift"
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }
}

extension Lint.Rule.`declarative manifest Tests`.Integration {
    @Test
    func `the rule's controls hold`() {
        for outcome in Lint.Rule.`declarative manifest`.outcomes() { #expect(outcome.holds, "\(outcome)") }
    }
}
