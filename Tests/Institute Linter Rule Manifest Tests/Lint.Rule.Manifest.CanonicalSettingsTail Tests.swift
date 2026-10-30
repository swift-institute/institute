import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `canonical settings tail Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`canonical settings tail Tests` {
    static func observation(
        _ source: Swift::String,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        Lint.Rule.`canonical settings tail`.observe(Lint.Source.parsed(from: source, file: file), .warning)
    }
}

extension Lint.Rule.`canonical settings tail Tests`.Unit {
    @Test
    func `the canonical tail is clean`() {
        let observation = Lint.Rule.`canonical settings tail Tests`.observation(
            "let package = Package(name: \"Fixture\")\n\n" + manifestCanonicalSettingsTail
        )
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `a manifest without a tail is flagged`() {
        let observation = Lint.Rule.`canonical settings tail Tests`.observation(
            "let package = Package(name: \"Fixture\")\n"
        )
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.hasPrefix("[canonical settings tail] [PACKAGE-SETTINGS-TAIL]:"))
        #expect(observation.findings[0].message.contains("must end with"))
    }
}

extension Lint.Rule.`canonical settings tail Tests`.`Edge Case` {
    @Test
    func `indentation differences are not drift`() {
        let reindented = manifestCanonicalSettingsTail.replacing("    ", with: "  ")
        let observation = Lint.Rule.`canonical settings tail Tests`.observation(
            "let package = Package(name: \"Fixture\")\n" + reindented
        )
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `a tail missing warnings as errors is drift`() {
        let drifted = manifestCanonicalSettingsTail.replacing("        .treatAllWarnings(as: .error),\n", with: "")
        let observation = Lint.Rule.`canonical settings tail Tests`.observation(
            "let package = Package(name: \"Fixture\")\n\n" + drifted
        )
        #expect(observation.findings.count == 1)
    }
}

extension Lint.Rule.`canonical settings tail Tests`.Integration {
    @Test
    func `code after the tail is drift`() {
        let observation = Lint.Rule.`canonical settings tail Tests`.observation(
            "let package = Package(name: \"Fixture\")\n" + manifestCanonicalSettingsTail + "let extra = 1\n",
            file: "Package@swift-6.4.swift"
        )
        #expect(observation.findings.count == 1)
    }
}

extension Lint.Rule.`canonical settings tail Tests`.Integration {
    static func repair(_ source: Swift::String) -> Lint.Rule.Repair.Proposal {
        Lint.Rule.`canonical settings tail`.repair(Lint.Source.parsed(from: source, file: "Package.swift"))
    }

    @Test
    func `repair replaces a drifted tail with the canonical one`() {
        let proposal = Self.repair(
            "let package = Package(name: \"Fixture\")\n\nfor target in package.targets {\n    target.swiftSettings = []\n}\n"
        )
        guard case .edits(let edits) = proposal, case .rewrite(_, let contents) = edits.first else {
            Issue.record("expected a rewrite, got \(proposal)")
            return
        }
        #expect(contents == "let package = Package(name: \"Fixture\")\n\n" + manifestCanonicalSettingsTail)
        #expect(Lint.Rule.`canonical settings tail Tests`.observation(contents).findings.isEmpty)
    }

    @Test
    func `repair appends the tail to a manifest without one`() {
        let proposal = Self.repair("let package = Package(name: \"Fixture\")\n\n\n")
        guard case .edits(let edits) = proposal, case .rewrite(_, let contents) = edits.first else {
            Issue.record("expected a rewrite, got \(proposal)")
            return
        }
        #expect(contents == "let package = Package(name: \"Fixture\")\n\n" + manifestCanonicalSettingsTail)
    }

    @Test
    func `repair leaves a canonical manifest unchanged`() {
        #expect(Self.repair("let package = Package(name: \"Fixture\")\n\n" + manifestCanonicalSettingsTail) == .unchanged)
    }

    @Test
    func `repair refuses when code follows the loop`() {
        let proposal = Self.repair(
            "let package = Package(name: \"Fixture\")\nfor target in package.targets {\n}\nlet extra = 1\n"
        )
        guard case .refused = proposal else {
            Issue.record("expected a refusal, got \(proposal)")
            return
        }
    }
}

extension Lint.Rule.`canonical settings tail Tests`.`Edge Case` {
    @Test
    func `repair leaves non-manifest files unchanged`() {
        let proposal = Lint.Rule.`canonical settings tail`.repair(
            Lint.Source.parsed(from: "struct Value {}\n", file: "Sources/Fixture/Value.swift")
        )
        #expect(proposal == .unchanged)
    }
}
