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

@testable import Institute_Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `file name nested path Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct Positive {}
        @Suite struct Negative {}
        @Suite struct Edge {}
        @Suite struct Exemption {}
        @Suite struct `Near Miss` {}
        @Suite struct `Self Firing` {}
    }
}

extension Lint.Rule.`file name nested path Tests` {
    static func findings(in source: String, file: String) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`file name nested path`.observe(parsed, .warning).findings
    }
}

// MARK: - Positive (mismatched basename)

extension Lint.Rule.`file name nested path Tests`.Positive {
    @Test
    func `top-level struct with mismatched basename fires`() {
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: "public struct Iterator {}",
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "file name nested path")
            #expect(findings[0].message.contains("Wrong.swift"))
            #expect(findings[0].message.contains("Iterator"))
        }
    }

    @Test
    func `platform-conditional top-level struct with mismatched basename still fires`() {
        // A type declared inside a top-level `#if` must be visible to the
        // by-hand top-level scan (IfConfigDeclSyntax descent) — otherwise
        // `primaryTypes.count == 0` and the rule silently returns no finding
        // for a file it should judge.
        let source = """
            #if os(macOS)
            public struct Iterator {}
            #endif
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `extension-nested struct with mismatched basename fires`() {
        let source = """
            extension Array.Dynamic {
                public struct Iterator {}
            }
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Array.Dynamic.Wrong.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("Array.Dynamic.Iterator"))
        }
    }
}

// MARK: - Negative (exact match)

extension Lint.Rule.`file name nested path Tests`.Negative {
    @Test
    func `top-level struct with exact match is permitted`() {
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: "public struct Iterator {}",
            file: "Sources/X/Iterator.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `nested-via-extension declaration with exact match is permitted`() {
        let source = """
            extension Array.Dynamic {
                public struct Iterator {}
            }
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Array.Dynamic.Iterator.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `conformance extension alongside the primary type is permitted when named exactly`() {
        let source = """
            public struct Iterator {}
            extension Iterator: Sendable {}
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Iterator.swift"
        )
        #expect(findings.isEmpty)
    }
}

// MARK: - Edge (namespace shell; hoisted-Protocol typealias)

extension Lint.Rule.`file name nested path Tests`.Edge {
    @Test
    func `namespace-enum shell with one nested type resolves to the nested type's path`() {
        let source = """
            enum Array {
                enum Dynamic {
                    struct Iterator {}
                }
            }
            """
        let matching = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Array.Dynamic.Iterator.swift"
        )
        #expect(matching.isEmpty)

        let mismatched = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Array.swift"
        )
        #expect(mismatched.count == 1)
        if mismatched.count == 1 {
            #expect(mismatched[0].message.contains("Array.Dynamic.Iterator"))
        }
    }

    @Test
    func `hoisted-Protocol idiom resolves to the canonical dotted name`() {
        let source = """
            public protocol __ArrayProtocol {}
            extension Array {
                public typealias `Protocol` = __ArrayProtocol
            }
            """
        let matching = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Array.Protocol.swift"
        )
        #expect(matching.isEmpty)

        let hoistedSpellingBasename = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/__ArrayProtocol.swift"
        )
        #expect(hoistedSpellingBasename.count == 1)
        if hoistedSpellingBasename.count == 1 {
            #expect(hoistedSpellingBasename[0].message.contains("Array.Protocol"))
        }
    }

    @Test
    func `cascade-suppression file where every extension carries a conformance is suppressed`() {
        let source = """
            public struct Iterator {}
            extension Iterator: Iterating {}
            extension Iterator where Iterator: Equatable {}
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `cascade-suppression file with only non-stdlib conformance extensions is suppressed`() {
        let source = """
            public struct Iterator {}
            extension Iterator: Iterating {}
            extension Iterator: Cursoring {}
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `cascade-suppression file with only where-clause extensions is suppressed`() {
        let source = """
            public struct Iterator<Element> {}
            extension Iterator where Element: Comparable {}
            extension Iterator where Element: Hashable {}
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a stdlib conformance under a where clause discriminates and is suppressed`() {
        let source = """
            public struct Iterator<Element> {}
            extension Iterator: Equatable where Element: Equatable {}
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a stdlib conformance alongside a non-stdlib one in one clause discriminates and is suppressed`() {
        let source = """
            public struct Iterator {}
            extension Iterator: Sendable, Iterating {}
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `the wrapping extension is not counted and discriminated others are suppressed`() {
        let source = """
            extension Array {
                public struct Iterator {}
            }
            extension Array.Iterator: Iterating {}
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }
}

// MARK: - Exemption (007-shaped basenames not firing)

extension Lint.Rule.`file name nested path Tests`.Exemption {
    @Test
    func `file outside Sources is out of scope`() {
        // The rule's stated surface is a source file under `Sources/`; a
        // Benchmarks/ (or Plugins/, Snippets/, package-root) file must not be
        // judged even though it isn't Tests/Experiments/Examples either.
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: "public struct Iterator {}",
            file: "Benchmarks/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `plus-conformance basename is 007's surface, not fired here`() {
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: "public struct Iterator {}",
            file: "Sources/X/Iterator+Sendable.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `where-clause basename is 007's surface, not fired here`() {
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: "public struct Iterator {}",
            file: "Sources/X/Iterator where Element Comparable.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `extension-only file has zero primary types and is out of scope`() {
        let source = """
            extension String {
                var doubled: String { self + self }
            }
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `rule-file shape with a private SyntaxVisitor helper is exempt per RULE-EXEMPT-7`() {
        // The house rule-file shape: a public `extension Lint.Rule { public
        // static let ... }` (the file's real, public API surface) paired
        // with a private `SyntaxVisitor` subclass implementation helper.
        // Without the [RULE-EXEMPT-7] exemption the collector resolves the
        // private visitor as the file's "primary type" and demands a rename
        // to its own (non-public) name.
        let source = """
            extension Lint.Rule {
                public static let `try optional` = Lint.Rule(id: "try optional", default: .warning) { _, _ in [] }
            }

            internal final class TryOptionalVisitor: SyntaxVisitor {
            }
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/Institute Linter Rule Try/Lint.Rule.Try.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a non-visitor class still resolves as the primary type`() {
        // Regression guard: [RULE-EXEMPT-7] must not blanket-exempt every
        // top-level class — only ones that subclass the SwiftSyntax visitor
        // family.
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: "public final class Iterator {}",
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `multiple top-level primary types are out of scope - owned by single type per file`() {
        let source = """
            struct Foo {}
            struct Bar {}
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }
}

// MARK: - Near-miss for every exemption

extension Lint.Rule.`file name nested path Tests`.`Near Miss` {
    @Test
    func `a bare member-only extension among conformance extensions still fires`() {
        let source = """
            public struct Iterator {}
            extension Iterator: Sendable {}
            extension Iterator {
                func helper() {}
            }
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `a stdlib-only conformance extension among conformance extensions still fires`() {
        // `extension Iterator: Sendable {}` stays in `Iterator.swift` by
        // design — 007 never moves it out, so it does not discriminate and
        // the rename remains the only fix.
        let source = """
            public struct Iterator {}
            extension Iterator: Sendable {}
            extension Iterator: Iterating {}
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `the wrapping extension is not counted and a bare member-only other still fires`() {
        let source = """
            extension Array {
                public struct Iterator {}
            }
            extension Array.Iterator {
                func helper() {}
            }
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("Array.Iterator"))
        }
    }

    @Test
    func `plus in a non-007 position still fires`() {
        // The `+` sits mid-basename in a shape that is not the 007
        // conformance-suffix convention's own excluded shape; 006 still
        // considers a plain mismatch against the primary type's own path.
        // Per the rule's literal predicate (any `+` in the basename is
        // 007's shape) this is excluded here too — recorded as a
        // near-miss control confirming the exclusion is by basename
        // content, not by position.
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: "public struct Iterator {}",
            file: "Sources/X/Wrong+Iterator.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `namespace shell with a second member is not a shell and does not descend`() {
        let source = """
            enum Array {
                enum Dynamic {
                    struct Iterator {}
                }
                static let tag = 1
            }
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Array.Dynamic.Iterator.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("'Array'"))
        }
    }

    @Test
    func `namespace shell with an enum case is not a shell and does not descend`() {
        let source = """
            enum Array {
                case dynamic
                enum Dynamic {
                    struct Iterator {}
                }
            }
            """
        let findings = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Array.Dynamic.Iterator.swift"
        )
        #expect(findings.count == 1)
    }
}

// MARK: - Self-firing

extension Lint.Rule.`file name nested path Tests`.`Self Firing` {
    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `self-firing control - a synthetic mismatch of this rule's own shape fires and its corrected name does not`()
    {
        let source = """
            extension Institute {
                struct Rule {}
            }
            """
        let mismatched = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(mismatched.count == 1)

        let corrected = Lint.Rule.`file name nested path Tests`.findings(
            in: source,
            file: "Sources/X/Institute.Rule.swift"
        )
        #expect(corrected.isEmpty)
    }
}
