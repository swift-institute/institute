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
import Text

@testable import Institute_Linter_Rule_Testing

extension Lint.Rule {
    @Suite
    struct `test file suffix Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`test file suffix Tests` {
    /// A minimal suite file body: one top-level `@Suite` type.
    static let suiteSource = "@Suite struct `Fixture Tests` {}"

    /// A minimal test file body with no suite: one top-level `@Test`
    /// function.
    static let testFunctionSource = "@Test func `fixture`() {}"

    /// A helper body carrying neither `@Suite` nor `@Test`.
    static let helperSource = "func makeFixture() -> Int { 0 }"

    static func findings(
        source: Swift::String,
        file: Swift::String
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`test file suffix`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`test file suffix Tests`.Unit {
    @Test
    func `joined Tests suffix on a Suite file is flagged with the rename`() {
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.suiteSource,
            file: "Tests/File Tests/FooTests.swift"
        )
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "test file suffix")
        #expect(findings.first?.severity == .warning)
        #expect(
            findings.first?.message
                == "[test file suffix] [TEST-009]: test file 'FooTests.swift' must "
                + "end in ' Tests.swift'; rename to 'Foo Tests.swift'"
        )
    }

    @Test
    func `Test-only file with no suffix is flagged with an appended suffix`() {
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.testFunctionSource,
            file: "Tests/File Tests/Behaviors.swift"
        )
        #expect(findings.count == 1)
        #expect(
            findings.first?.message
                == "[test file suffix] [TEST-009]: test file 'Behaviors.swift' must "
                + "end in ' Tests.swift'; rename to 'Behaviors Tests.swift'"
        )
    }

    @Test
    func `space-separated Tests suffix is permitted`() {
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.suiteSource,
            file: "Tests/File Tests/File.Directory Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `diagnostic is located at the first Suite or Test declaration`() {
        let source = """
            import Testing

            func makeFixture() -> Int { 0 }

            @Suite struct `Fixture Tests` {}
            """
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: source,
            file: "Tests/File Tests/FooTests.swift"
        )
        #expect(findings.count == 1)
        #expect(findings.first?.location.line == 5)
        #expect(findings.first?.location.column == 1)
    }
}

extension Lint.Rule.`test file suffix Tests`.`Edge Case` {
    @Test
    func `subject segment containing Tests does not fire`() {
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.suiteSource,
            file: "Tests/File Tests/Tests.Helpers Tests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `trailing whitespace variance is a rename not a pass`() {
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.suiteSource,
            file: "Tests/File Tests/Foo Tests .swift"
        )
        #expect(findings.count == 1)
        #expect(
            findings.first?.message
                == "[test file suffix] [TEST-009]: test file 'Foo Tests .swift' must "
                + "end in ' Tests.swift'; rename to 'Foo Tests.swift'"
        )
    }

    @Test
    func `double-spaced Tests suffix remains nonconforming`() {
        // #24 defect 8: `hasSuffix(" Tests")` alone also accepts a
        // double-spaced basename, since "  Tests" itself ends in
        // " Tests" — exactly one space must precede `Tests`.
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.suiteSource,
            file: "Tests/File Tests/Foo  Tests.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `dot-separated Tests suffix remains nonconforming`() {
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.suiteSource,
            file: "Tests/File Tests/File.Directory.Tests.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `bare Tests basename renames to Tests Tests`() {
        // #24 nit: a file literally named `Tests.swift` — the subject
        // strips to empty after dropping the trailing "Tests", so the
        // rename falls back to appending " Tests" to the (empty) base
        // rather than producing a leading-space or empty subject.
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.suiteSource,
            file: "Tests/File Tests/Tests.swift"
        )
        #expect(findings.count == 1)
        #expect(
            findings.first?.message
                == "[test file suffix] [TEST-009]: test file 'Tests.swift' must "
                + "end in ' Tests.swift'; rename to 'Tests Tests.swift'"
        )
    }

    @Test
    func `relative path segment does not defeat scanning via the dot-prefix exemption`() {
        // The hidden-component guard is deliberately also true for a `..`
        // segment (dot-prefixed) — documented behavior, not a design
        // change here. A literal hidden directory (e.g. `.build`) is the
        // exemption's actual target.
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.suiteSource,
            file: "Tests/.build/FooTests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `nested Test functions inside a top-level type are detected`() {
        let source = """
            extension File.Tests.Unit {
              @Test func `walks the directory`() {}
            }
            """
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: source,
            file: "Tests/File Tests/File.WalkTests.swift"
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`test file suffix Tests`.Integration {
    @Test
    func `helper file with no Suite or Test declarations must not fire`() {
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.helperSource,
            file: "Tests/Support/Fixture.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `near-miss helper file declaring one Test must fire`() {
        let source = """
            func makeFixture() -> Int { 0 }

            @Test func `fixture round-trips`() {}
            """
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: source,
            file: "Tests/Support/Fixture.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `non-test targets are out of scope entirely`() {
        let findings = Lint.Rule.`test file suffix Tests`.findings(
            source: Lint.Rule.`test file suffix Tests`.suiteSource,
            file: "Sources/File/FileTests.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `self-firing control catches this suite under the legacy joined name`() {
        // This very file's own source, under the legacy joined basename,
        // must fire; under its actual conforming basename it must not.
        let path = #filePath
        let conformingName = path.split(separator: "/").last.map(Swift::String.init) ?? ""
        #expect(conformingName.hasSuffix(" Tests.swift"))
        let joinedName =
            Swift::String(conformingName.dropLast(" Tests.swift".count)) + "Tests.swift"
        let firing = Lint.Rule.`test file suffix Tests`.findings(
            source: "@Suite struct `test file suffix Tests` {}",
            file: "Tests/Institute Linter Rule Testing Tests/\(joinedName)"
        )
        let conforming = Lint.Rule.`test file suffix Tests`.findings(
            source: "@Suite struct `test file suffix Tests` {}",
            file: "Tests/Institute Linter Rule Testing Tests/\(conformingName)"
        )
        #expect(firing.count == 1)
        #expect(conforming.isEmpty)
    }
}
