import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_SQL

@Suite
struct `grdb import Tests` {
    @Suite struct Unit {}
    @Suite struct Integration {}
}

extension `grdb import Tests` {
    static func findings(_ source: Swift::String, file: Swift::String = "Sources/Affairs SQLite/Store.swift") -> [Diagnostic.Record] {
        Lint.Rule.`grdb import`.observe(Lint.Source.parsed(from: source, file: file), .warning).findings
    }
}

extension `grdb import Tests`.Unit {
    @Test(arguments: [
        "import GRDB",
        "public import GRDB",
        "@_exported import GRDB",
        "import struct GRDB.DatabaseQueue",
        "@testable import GRDB",
    ])
    func `every import of GRDB fires`(source: Swift::String) {
        #expect(`grdb import Tests`.findings(source).count == 1)
    }

    @Test
    func `other imports do not fire`() {
        #expect(`grdb import Tests`.findings("import SQLite\nimport GRDBQuery\nimport SQL").isEmpty)
    }

    @Test
    func `manifest names of the GRDB package fire`() {
        let findings = `grdb import Tests`.findings(
            """
            let package = Package(
              dependencies: [.package(url: "https://github.com/groue/GRDB.swift", from: "7.6.0")],
              targets: [.target(name: "A", dependencies: [.product(name: "GRDB", package: "GRDB.swift")])]
            )
            """,
            file: "Package.swift"
        )
        #expect(findings.count == 2)
    }

    @Test
    func `the same strings outside a manifest do not fire`() {
        #expect(`grdb import Tests`.findings(#"let name = "GRDB.swift""#).isEmpty)
    }

    @Test(arguments: ["Package@swift-6.0.swift", "Package@swift-5.10.swift", "Nested/Package.swift"])
    func `a versioned or nested manifest fires`(file: Swift::String) {
        #expect(`grdb import Tests`.findings(#"let p = Package(name: "GRDB.swift")"#, file: file).count == 1, "\(file)")
    }

    @Test(arguments: ["MyPackage.swift", "Sources/X/MyPackage.swift", "Package@swift.swift", "Package@6.0.swift"])
    func `near miss: a file whose name only ends in Package.swift is not a manifest`(file: Swift::String) {
        #expect(`grdb import Tests`.findings(#"let p = Package(name: "GRDB.swift")"#, file: file).isEmpty, "\(file)")
    }
}

extension `grdb import Tests`.Integration {
    @Test
    func `controls hold`() {
        let outcomes = Lint.Rule.`grdb import`.outcomes()
        #expect(outcomes.contains { $0.expected > 0 })
        for outcome in outcomes { #expect(outcome.holds, "\(outcome)") }
    }
}
