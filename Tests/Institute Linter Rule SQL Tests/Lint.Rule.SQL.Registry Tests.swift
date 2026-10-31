import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_SQL

@Suite
struct `sql registry Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Exemption {}
    @Suite struct Registry {}
    @Suite struct Integration {}
}

extension `sql registry Tests` {
    static let library = """
        extension Library {
          func conditions() -> [SQLQueryExpression<Bool>] {
            [#sql(#""actionable""#), #sql(#""flagged""#)]
          }
          static let pending = #sql(#""pending""#)
        }
        """

    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Affairs SQLite/Library.swift",
        exceptions: Lint.SQL.Exceptions = .none
    ) -> [Diagnostic.Record] {
        Lint.Rule.`sql registry`(exceptions: exceptions)
            .observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }
}

extension `sql registry Tests`.Unit {
    @Test
    func `unlisted sites fire once each`() {
        let findings = `sql registry Tests`.findings(`sql registry Tests`.library)
        #expect(findings.count == 3)
        #expect(findings[0].message.contains("`Library.conditions()`"))
        #expect(findings[2].message.contains("`Library.pending`"))
    }

    @Test
    func `listed sites with matching counts are clean`() {
        let findings = `sql registry Tests`.findings(
            `sql registry Tests`.library,
            exceptions: [
                .init(
                    file: "Sources/Affairs SQLite/Library.swift",
                    declaration: "Library.conditions()",
                    sites: 2,
                    reason: "mailbox predicates over a JSON column"
                ),
                .init(
                    file: "Sources/Affairs SQLite/Library.swift",
                    declaration: "Library.pending",
                    reason: "boolean column used as a predicate"
                ),
            ]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `site count mismatch fires`() {
        let findings = `sql registry Tests`.findings(
            `sql registry Tests`.library,
            exceptions: [
                .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "Library.conditions()", reason: "r"),
                .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "Library.pending", reason: "r"),
            ]
        )
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("listed with 1") == true)
    }

    @Test
    func `stale declaration entry fires`() {
        let findings = `sql registry Tests`.findings(
            "struct Library {}",
            exceptions: [
                .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "Library.gone()", reason: "r")
            ]
        )
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("stale entry") == true)
    }

    @Test
    func `message says it checks presence not soundness`() {
        let message = `sql registry Tests`.findings("let x = #sql(\"1\")").first?.message ?? ""
        #expect(message.contains("does not check that the reason is sound"))
        #expect(message.contains("Fix:"))
    }
}

extension `sql registry Tests`.Exemption {
    @Test
    func `schema target is exempt and inapplicable`() {
        let observation = Lint.Rule.`sql registry`(exceptions: .none).observe(
            Lint.Source.parsed(from: "let v = #sql(\"CREATE TABLE t (id)\")", file: "Sources/Affairs Schema/V1.swift"),
            .warning
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test
    func `a test target is exempt and inapplicable`() {
        let observation = Lint.Rule.`sql registry`(exceptions: .none).observe(
            Lint.Source.parsed(from: "let v = #sql(\"SELECT 1\")", file: "Tests/Affairs Tests/Schema.Tests.swift"),
            .warning
        )
        #expect(observation.findings.isEmpty)
        #expect(observation.applicability == .inapplicable)
    }

    @Test
    func `schema target in a nested directory is exempt`() {
        let findings = `sql registry Tests`.findings(
            "let v = #sql(\"1\")",
            file: "Sources/Affairs Schema/Versions/V1.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test(arguments: [
        "Test.swift",
        "Affairs Schema.swift",
        "Sources/Affairs Schema.swift",
        "Sources/Schema/V1.swift",
        "Sources/AffairsSchema/V1.swift",
        "Sources/Affairs Schema Tests/V1.swift",
        "Sources/Affairs/Affairs Schema/V1.swift",
        "Schema/ Schema/V1.swift",
        "Sources/ Schema/V1.swift",
    ])
    func `near misses still fire`(file: Swift::String) {
        #expect(`sql registry Tests`.findings("let v = #sql(\"1\")", file: file).count == 1)
    }
}

extension `sql registry Tests`.`Edge Case` {
    @Test
    func `top-level and nested declaration identities`() {
        let findings = `sql registry Tests`.findings(
            """
            let a = #sql("1")
            enum Outer {
              struct Inner {
                init(x: Int, _ y: Int) { _ = #sql("2") }
                subscript(index: Int) -> Int { _ = #sql("3"); return 0 }
              }
            }
            """
        )
        let messages = findings.map(\.message)
        #expect(messages.count == 3)
        #expect(messages[0].contains("`(top level)`") || messages[0].contains("`a`"))
        #expect(messages[1].contains("`Outer.Inner.init(x:_:)`"))
        #expect(messages[2].contains("`Outer.Inner.subscript(index:)`"))
    }

    @Test
    func `entry for another file does not cover the site`() {
        let findings = `sql registry Tests`.findings(
            "let a = #sql(\"1\")",
            exceptions: [.init(file: "Sources/Other/Library.swift", declaration: "a", reason: "r")]
        )
        #expect(findings.count == 1)
    }
}

extension `sql registry Tests`.Registry {
    static let manifest = "// swift-tools-version: 6.4\nimport PackageDescription\n"

    static func registryFindings(_ exceptions: Lint.SQL.Exceptions) throws -> [Diagnostic.Record] {
        let fixture = try Lint.Source.Fixture(files: [
            "Package.swift": manifest,
            "Sources/Affairs SQLite/Library.swift": "let a = #sql(\"1\")",
        ])
        return Lint.Rule.`sql registry`(exceptions: exceptions)
            .observe(fixture.parsed("Package.swift"), .warning).findings
    }

    @Test
    func `sound entry is clean at the package root`() throws {
        let findings = try Self.registryFindings([
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "a", reason: "fragment")
        ])
        #expect(findings.isEmpty)
    }

    @Test
    func `missing file is a stale entry`() throws {
        let findings = try Self.registryFindings([
            .init(file: "Sources/Affairs SQLite/Gone.swift", declaration: "a", reason: "fragment")
        ])
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("does not exist") == true)
    }

    @Test
    func `empty and multi-line reasons fire`() throws {
        let findings = try Self.registryFindings([
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "a", reason: "  "),
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "b", reason: "one\ntwo"),
        ])
        #expect(findings.count == 2)
    }

    @Test
    func `missing API reason requires a swift-sql issue`() throws {
        let unlinked = try Self.registryFindings([
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "a", reason: "swift-sql lacks json_each")
        ])
        #expect(unlinked.count == 1)
        let wrongRepository = try Self.registryFindings([
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "a", reason: "missing API, swift-compositions/swift-sqlite#4")
        ])
        #expect(wrongRepository.count == 1)
        let noNumber = try Self.registryFindings([
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "a", reason: "missing API, swift-compositions/swift-sql#")
        ])
        #expect(noNumber.count == 1)
        let linked = try Self.registryFindings([
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "a", reason: "Missing json_each (swift-compositions/swift-sql#12)")
        ])
        #expect(linked.isEmpty)
        let dismissing = try Self.registryFindings([
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "a", reason: "dismissing blacksmith rows")
        ])
        #expect(dismissing.isEmpty)
    }

    @Test
    func `duplicate, zero-site and schema entries fire`() throws {
        let findings = try Self.registryFindings([
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "a", reason: "r"),
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "a", reason: "r"),
            .init(file: "Sources/Affairs SQLite/Library.swift", declaration: "b", sites: 0, reason: "r"),
            .init(file: "Sources/Affairs Schema/V1.swift", declaration: "v", reason: "r"),
        ])
        let messages = findings.map(\.message)
        #expect(messages.contains { $0.contains("listed more than once") })
        #expect(messages.contains { $0.contains("`sites` is 0") })
        #expect(messages.contains { $0.contains("`… Schema` target, where") })
    }

    @Test
    func `nested Package.swift does not run root checks`() throws {
        let fixture = try Lint.Source.Fixture(files: ["Tools/Package.swift": Self.manifest])
        let findings = Lint.Rule.`sql registry`(exceptions: [
            .init(file: "Sources/Gone.swift", declaration: "a", reason: "")
        ]).observe(fixture.parsed("Tools/Package.swift"), .warning).findings
        #expect(findings.isEmpty)
    }
}

extension `sql registry Tests`.Integration {
    @Test
    func `controls hold`() {
        let outcomes = Lint.Rule.`sql registry`(exceptions: .none).outcomes()
        #expect(outcomes.contains { $0.expected > 0 })
        for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
    }
}
