// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-institute-linter-rules open source project
//
// Copyright (c) 2026 Coen ten Thije Boonkkamp and the swift-institute-linter-rules project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Naming

extension Lint.Rule {
    @Suite
    struct `path name grammar Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`path name grammar Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`path name grammar`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`path name grammar Tests`.Unit {
    // Positive control — the known real instance class: pre-split
    // institute-application's concatenated `InstituteArchitecture*`
    // directories (#65's cited fixture pair).
    @Test
    func `concatenated directory under Sources is flagged`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Command {}",
            file: "Sources/InstituteArchitectureCLI/Command.swift"
        )
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "path name grammar")
        #expect(findings.first?.message.contains("InstituteArchitectureCLI") == true)
    }

    @Test
    func `concatenated directory under Tests is flagged`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Probe {}",
            file: "Tests/InstituteApplicationTests/Probe.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `concatenated basename segment naming a type declared elsewhere is flagged`() {
        // Passes [API-IMPL-006] (basename matches the nested path) and
        // never reaches [API-NAME-001] here (the compound outer type is
        // declared in another file) — this rule's residual class.
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "extension InstituteArchitectureCLI { struct Command {} }",
            file: "Sources/Institute Application/InstituteArchitectureCLI.Command.swift"
        )
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("file name segment") == true)
    }

    @Test
    func `a repeated compound segment is reported once`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "extension PaymentMethods { struct PaymentMethods {} }",
            file: "Sources/Payments/PaymentMethods.PaymentMethods.swift"
        )
        #expect(findings.count == 1)
    }

    // Negative controls — current correct spellings.
    @Test
    func `spaced directory and dotted basename are permitted`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "extension Institute { struct Application {} }",
            file: "Sources/Institute Application/Institute.Application.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `spaced test target directory with Tests suffix is permitted`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Probe {}",
            file: "Tests/Institute Linter Rule Naming Tests/Probe.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `multi word spaced directory is permitted`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct CLI {}",
            file: "Sources/Institute Architecture CLI/CLI.swift"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`path name grammar Tests`.`Edge Case` {
    @Test
    func `bare filename without a directory is out of surface`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Fixture {}",
            file: "Fixture.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `docc catalogue directory is exempt`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Snippet {}",
            file: "Sources/Institute Application/InstituteApplication.docc/Snippet.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `canonical dot snapshots directory is exempt`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Fixture {}",
            file: "Tests/Institute Application Snapshot Tests/.snapshots/Fixture.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `legacy snapshots directory is flagged`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Fixture {}",
            file: "Tests/Institute Application Snapshot Tests/__Snapshots__/Fixture.swift"
        )
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "path name grammar")
        #expect(findings.first?.message.contains(".snapshots") == true)
    }

    @Test
    func `snapshot directory case near miss is flagged`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Fixture {}",
            file: "Tests/Institute Application Snapshot Tests/.Snapshots/Fixture.swift"
        )
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains(".Snapshots") == true)
    }

    @Test
    func `nested test package path is covered after its Tests root`() {
        // Nested test packages live under Tests/ with their own manifest;
        // their target directories bind to the same grammar.
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Probe {}",
            file: "swift-example/Tests/ExampleSnapshotTests/Probe.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `file outside Sources and Tests is out of surface`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct FooBar {}",
            file: "Plugins/BadPluginName/Plugin.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `extension only file with descriptive basename is recorded residue`() {
        // The linter rule packs' own house shape: extension + visitor
        // subclass, no primary nominal type — no anchor, no finding.
        let source = """
            import SwiftSyntax
            extension Lint.Rule {
              public static let example = 1
            }
            internal final class NamingExampleVisitor: SyntaxVisitor {}
            """
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: source,
            file: "Sources/Institute Linter Rule Naming/Lint.Rule.Naming.CompoundType.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `conformance suffix after plus is not policed`() {
        // The `+` suffix is [API-IMPL-007]'s surface; only the prefix
        // segments bind here.
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "extension Array { struct Dynamic {} }",
            file: "Sources/Collections/Array.Dynamic+CustomStringConvertible.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `brand token directory is exempt through the shared predicate`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Client {}",
            file: "Sources/GitHub Client/Client.swift"
        )
        #expect(findings.isEmpty)
    }

    // Near-miss — a type whose name legitimately differs from the file's
    // basename is [API-IMPL-006]'s finding, never this rule's: the
    // basename's own segments are grammatical, so this rule stays silent.
    @Test
    func `mismatched but grammatical basename is 006's surface not this rule's`() {
        let findings = Lint.Rule.`path name grammar Tests`.findings(
            in: "struct Right {}",
            file: "Sources/Institute Application/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }
}
