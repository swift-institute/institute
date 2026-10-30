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
    struct `redundant prefix Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`redundant prefix Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`redundant prefix`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`redundant prefix Tests`.Unit {
    @Test
    func `Walk-WalkOptions inside Walk is flagged`() {
        let source = """
            enum Walk {
                struct WalkOptions {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "redundant prefix")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `File-FileError inside File is flagged`() {
        let source = """
            enum File {
                enum FileError {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension Manifest with ManifestEntry is flagged`() {
        let source = """
            extension Manifest {
                struct ManifestEntry {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested extension on member type uses last component`() {
        // `extension A.B.C { struct CFoo {} }` — enclosing = `C` → flagged.
        let source = """
            extension A.B.C {
                struct CFoo {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `class hierarchy Foo-FooBar is flagged`() {
        let source = """
            class Foo {
                class FooBar {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `actor Service-ServiceState is flagged`() {
        let source = """
            actor Service {
                struct ServiceState {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending nested types are all flagged`() {
        let source = """
            enum Walk {
                struct WalkOptions {}
                struct WalkResult {}
                enum WalkError {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.`redundant prefix Tests`.`Edge Case` {
    @Test
    func `bare Options inside Walk is NOT flagged`() {
        let source = """
            enum Walk {
                struct Options {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `top-level Walk has no enclosing - NOT flagged`() {
        let source = "enum Walk {}"
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `top-level WalkOptions outside Walk is NOT flagged`() {
        // No enclosing namespace; CompoundType (API-NAME-001) handles this case.
        let source = "struct WalkOptions {}"
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `unrelated nested name Bar inside Walk is NOT flagged`() {
        let source = """
            enum Walk {
                struct Bar {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `prefix-substring without uppercase boundary is NOT flagged`() {
        // `Foobar` starts with `Foo` but `bar` is lowercase — no compound
        // boundary, so this is a single-word name `Foobar`, not redundant.
        let source = """
            enum Foo {
                struct Foobar {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `same-name nested type Foo inside Foo is NOT flagged`() {
        // Exact match; no suffix; not a compound.
        let source = """
            enum Foo {
                struct Foo {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `triple nesting with redundancy at innermost is flagged`() {
        let source = """
            enum Outer {
                enum Walk {
                    struct WalkOptions {}
                }
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `sugar-typed extension (array) has no enclosing name - NOT flagged`() {
        // `extension [Byte] { struct View {} }` — the extended type is an
        // ArrayTypeSyntax, which has no nested-name component, so `View`
        // must not be treated as redundant against an empty enclosing name.
        let source = """
            extension [Byte] {
                struct View {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `sugar-typed extension (optional) has no enclosing name - NOT flagged`() {
        let source = """
            extension Byte? {
                struct View {}
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `triple nesting with redundancy at middle level is flagged`() {
        // `enum File { enum FileSystem { struct X {} } }` — FileSystem flagged.
        let source = """
            enum File {
                enum FileSystem {
                    struct X {}
                }
            }
            """
        let findings = Lint.Rule.`redundant prefix Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
