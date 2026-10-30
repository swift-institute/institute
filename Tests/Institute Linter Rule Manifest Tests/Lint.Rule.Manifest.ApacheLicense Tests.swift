import Lint
import Linter_Rules_Test_Support
import SwiftParser
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `apache license Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`apache license Tests` {
    static func observe(
        license: Lint.Source.Index.License,
        file: Swift::String = "Package.swift"
    ) -> Lint.Rule.Observation {
        let source = "let package = Package(name: \"Fixture\")"
        var index = Lint.Source.Index.collect(from: Parser.parse(source: source))
        index.license = license
        return Lint.Rule.`apache license`
            .observe(Lint.Source.parsed(from: source, file: file, index: index), .warning)
    }
}

extension Lint.Rule.`apache license Tests`.Unit {
    @Test
    func `the full Apache License 2.0 text is clean`() {
        let license = "                                 Apache License\n" + manifestApacheLicenseTerms
        #expect(Lint.Rule.`apache license Tests`.observe(license: .text(license)).findings.isEmpty)
    }

    @Test
    func `a missing license file is flagged`() {
        let findings = Lint.Rule.`apache license Tests`.observe(license: .absent).findings
        #expect(findings.count == 1)
        #expect(findings.first?.message.hasPrefix("[apache license]:") == true)
    }

    @Test
    func `an MIT license is flagged`() {
        let mit = "MIT License\n\nCopyright (c) 2026 Swift Institute\n\nPermission is hereby granted"
        #expect(Lint.Rule.`apache license Tests`.observe(license: .text(mit)).findings.count == 1)
    }

    @Test
    func `the short Apache header alone is flagged`() {
        let header = "Licensed under the Apache License, Version 2.0 (the \"License\");"
        #expect(Lint.Rule.`apache license Tests`.observe(license: .text(header)).findings.count == 1)
    }
}

extension Lint.Rule.`apache license Tests`.`Edge Case` {
    @Test
    func `reflowed and emphasised text is still the Apache text`() {
        let reflowed =
            "# Apache License\n\n**"
            + manifestApacheLicenseTerms
            .split(separator: "\n").joined(separator: " ") + "**"
        #expect(Lint.Rule.`apache license Tests`.observe(license: .text(reflowed)).findings.isEmpty)
    }

    @Test
    func `a text missing one definition is flagged`() {
        let missing = manifestApacheLicenseTerms.replacing("\"Licensor\" shall mean", with: "")
        #expect(Lint.Rule.`apache license Tests`.observe(license: .text(missing)).findings.count == 1)
    }

    @Test
    func `a nested manifest and an unread license are not observed`() {
        let nested = Lint.Rule.`apache license Tests`.observe(license: .absent, file: "Runner/Package.swift")
        #expect(nested.applicability == .inapplicable)
        let unread = Lint.Rule.`apache license Tests`.observe(license: .unread)
        #expect(unread.applicability == .inapplicable)
    }

    @Test
    func `a source file is not observed`() {
        let source = Lint.Rule.`apache license Tests`.observe(
            license: .absent,
            file: "Sources/Fixture/Fixture.swift"
        )
        #expect(source.applicability == .inapplicable)
    }
}

extension Lint.Rule.`apache license Tests`.`Edge Case` {
    @Test
    func `a licence naming an upstream holder is exempt`() {
        let pointFree = "MIT License\n\nCopyright (c) 2025 Point-Free, Inc.\n\nPermission is hereby granted"
        #expect(Lint.Rule.`apache license Tests`.observe(license: .text(pointFree)).findings.isEmpty)
    }

    @Test
    func `a licence naming our own holders is not exempt`() {
        for holder in ["Coen ten Thije Boonkkamp", "Swift Institute"] {
            let mit = "MIT License\n\nCopyright (c) 2025-2026 \(holder)\n\nPermission is hereby granted"
            #expect(Lint.Rule.`apache license Tests`.observe(license: .text(mit)).findings.count == 1)
        }
    }

    @Test
    func `the licence author's own copyright is not an upstream holder`() {
        let agpl = "GNU Affero General Public License\n\n_Copyright © 2007 Free Software Foundation, Inc._"
        #expect(Lint.Rule.`apache license Tests`.observe(license: .text(agpl)).findings.count == 1)
    }

    @Test
    func `a copyright line without a holder is not an exemption`() {
        let bare = "Copyright (c) 2026\n\nAll rights reserved."
        #expect(Lint.Rule.`apache license Tests`.observe(license: .text(bare)).findings.count == 1)
    }
}
