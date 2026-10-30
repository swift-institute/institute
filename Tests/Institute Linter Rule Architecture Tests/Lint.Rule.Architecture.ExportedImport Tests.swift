import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Architecture

extension Lint.Rule {
    @Suite
    struct `exported import Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`exported import Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Fixture/exports.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`exported import`
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
            .findings
    }
}

extension Lint.Rule.`exported import Tests`.Unit {
    @Test
    func `every exported import outside exports swift is flagged`() {
        let findings = Lint.Rule.`exported import Tests`.findings(
            """
            @_exported public import Owner
            @_exported import Other
            public import Plain
            """,
            file: "Sources/Fixture/Fixture.swift"
        )
        #expect(findings.count == 2)
        #expect(findings[0].message.hasPrefix("[exported import] [SOURCE-EXPORTED-IMPORT]:"))
    }

    @Test
    func `plain imports are clean`() {
        let findings = Lint.Rule.`exported import Tests`.findings(
            "public import Owner\ninternal import Other"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`exported import Tests`.`Edge Case` {
    @Test
    func `a public whole-module re-export in a target's exports swift is exempt`() {
        let findings = Lint.Rule.`exported import Tests`.findings(
            """
            @_exported public import Owner
            @_exported public import Other_Module
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `the exemption holds for an absolute checkout path`() {
        let findings = Lint.Rule.`exported import Tests`.findings(
            "@_exported public import Owner",
            file: "/workspace/swift-fixture/Sources/Fixture Core/exports.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a non-public or scoped re-export in exports swift is still flagged`() {
        let findings = Lint.Rule.`exported import Tests`.findings(
            """
            @_exported import Owner
            @_exported package import Other
            @_exported public import struct Owner.Value
            """
        )
        #expect(findings.count == 3)
    }

    @Test
    func `files named like exports swift are still flagged`() {
        for file in [
            "Sources/Fixture/Exports.swift",
            "Sources/Fixture/Fixture exports.swift",
            "Sources/Fixture/exports.swift.swift",
            "Sources/exports.swift/Fixture.swift",
            "Sources/Fixture/Nested/exports.swift",
            "Sources/exports.swift",
        ] {
            let findings = Lint.Rule.`exported import Tests`.findings(
                "@_exported public import Owner",
                file: file
            )
            #expect(findings.count == 1, "\(file)")
        }
    }

    @Test
    func `tests are out of scope`() {
        let findings = Lint.Rule.`exported import Tests`.findings(
            "@_exported import Owner",
            file: "Tests/Fixture Tests/exports.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a scoped exported import is flagged`() {
        let findings = Lint.Rule.`exported import Tests`.findings(
            "@_exported import struct Owner.Value"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`exported import Tests`.Integration {
    @Test
    func `an exported import behind a condition is flagged`() {
        let findings = Lint.Rule.`exported import Tests`.findings(
            """
            #if canImport(Owner)
            @_exported public import Owner
            #endif
            """,
            file: "/workspace/swift-fixture/Sources/Fixture/Fixture.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `a conditional re-export in exports swift is exempt`() {
        let findings = Lint.Rule.`exported import Tests`.findings(
            """
            #if canImport(Owner)
            @_exported public import Owner
            #endif
            """,
            file: "/workspace/swift-fixture/Sources/Fixture/exports.swift"
        )
        #expect(findings.isEmpty)
    }
}
