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
    struct `extension file naming Tests` {
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

extension Lint.Rule.`extension file naming Tests` {
    static func findings(in source: String, file: String) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`extension file naming`.observe(parsed, .warning).findings
    }
}

// MARK: - Positive (one per class, plus the 497-shape and mixed-base)

extension Lint.Rule.`extension file naming Tests`.Positive {
    @Test
    func `conformance-adding extension with wrong or missing plus segment fires`() {
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator: Iterating {}",
            file: "Sources/X/Iterator.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "extension file naming")
            #expect(findings[0].message.contains("Iterator+Iterating.swift"))
        }
    }

    @Test
    func `stdlib-only conformance extension file fires relocation regardless of basename`() {
        // `extension Custom: Sendable {}` belongs in `Custom.swift`, directly
        // under the type declaration — a `Custom+Sendable.swift` sibling has
        // no lawful name, so even the would-be-canonical basename fires.
        let source = "extension Iterator: Sendable {}"
        let canonicalLooking = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator+Sendable.swift"
        )
        #expect(canonicalLooking.count == 1)
        if canonicalLooking.count == 1 {
            #expect(canonicalLooking[0].message.contains("standard-library conformances"))
            #expect(canonicalLooking[0].message.contains("'Iterator.swift'"))
        }

        let bare = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator.swift"
        )
        #expect(bare.count == 1)
    }

    @Test
    func `module-qualified stdlib conformance is still stdlib`() {
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator: Swift.Hashable { func hash(into hasher: inout Hasher) {} }",
            file: "Sources/X/Iterator+Hashable.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("standard-library conformances"))
        }
    }

    @Test
    func `several stdlib-only conformance extensions in one file fire once`() {
        let source = """
            extension Iterator: Sendable {}
            extension Iterator: Equatable {}
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator+Sendable.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `stdlib conformance alongside a non-stdlib one does not name the file`() {
        // The non-stdlib conformance owns the `<Base>+<Conformance>` shape;
        // the stdlib one is dropped from classification entirely.
        let source = "extension Iterator: Sendable, Iterating {}"
        let namedForStdlib = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator+Sendable.swift"
        )
        #expect(namedForStdlib.count == 1)
        if namedForStdlib.count == 1 {
            #expect(namedForStdlib[0].message.contains("Iterator+Iterating.swift"))
        }
    }

    @Test
    func `where-clause discriminated extension with wrong basename fires`() {
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator where Element: Comparable {}",
            file: "Sources/X/Iterator.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("Iterator where <discriminator>.swift"))
        }
    }

    @Test
    func `member-only extension file with a topic segment fires`() {
        // `+` names a type; a free-text grouping word after it has no
        // declaration to resolve to. The members belong in `Iterator.swift`.
        let source = """
            extension Iterator {
                func next() -> Element? { nil }
            }
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator+Iteration.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("'Iterator.swift'"))
        }
    }

    @Test
    func `mixed-base extension file fires`() {
        let source = """
            extension Iterator {
                func next() -> Element? { nil }
            }
            extension Cursor {
                func advance() {}
            }
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("mixes extensions on different base types"))
        }
    }

    @Test
    func `mixed-base file with a sugared extended type is still detected`() {
        // Regression guard: `structureDottedName` returns
        // nil for a sugared extended type (`[Int]`), and a `compactMap` over
        // that would silently drop it from the base set, letting a
        // genuinely mixed-base file pass `bases.count == 1` undetected.
        let source = """
            extension [Int] {
                var doubled: [Int] { self }
            }
            extension Iterator {
                func next() -> Element? { nil }
            }
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].message.contains("mixes extensions on different base types"))
        }
    }

    @Test
    func `sugared first extended type does not exempt a misnamed remainder`() {
        // Regression guard: when the FIRST extension's extended type falls
        // through to nil, the old `guard let base = ... else { return [] }`
        // exempted the whole file even though the remaining extension is on
        // a different, resolvable base.
        let source = """
            extension [Int] {
                var doubled: [Int] { self }
            }
            extension Cursor {
                func advance() {}
            }
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.count == 1)
    }
}

// MARK: - Negative (one per class)

extension Lint.Rule.`extension file naming Tests`.Negative {
    @Test
    func `conformance-adding extension with correct plus segment is permitted`() {
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator: Iterating {}",
            file: "Sources/X/Iterator+Iterating.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `stdlib conformance alongside a non-stdlib one accepts the non-stdlib name`() {
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator: Sendable, Iterating {}",
            file: "Sources/X/Iterator+Iterating.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `stdlib conformance extension next to a member-only extension is the type's own file`() {
        // Not stdlib-ONLY as a file: the member-only extension makes this
        // the type's own file, and the `Sendable` extension is dropped from
        // the conformance classification rather than naming the file.
        let source = """
            extension Iterator: Sendable {}
            extension Iterator {
                func next() -> Element? { nil }
            }
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `module-qualified conformance accepts the leaf-component basename`() {
        // `extension Array.Dynamic: Institute.Iterating` records its
        // conformance as `Institute.Iterating`, but the canonical basename
        // names only the leaf `Iterating` — no repository names files
        // `Array.Dynamic+Institute.Iterating.swift`.
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Array.Dynamic: Institute.Iterating {}",
            file: "Sources/X/Array.Dynamic+Iterating.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `module-qualified conformance basename still fires when genuinely wrong`() {
        // Regression guard: the leaf-component acceptance must not turn into
        // a blanket pass — a basename naming an unrelated conformance still
        // fires.
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Array.Dynamic: Institute.Iterating {}",
            file: "Sources/X/Array.Dynamic+Cursoring.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `file outside Sources is out of scope`() {
        // The rule's stated surface is a source file under `Sources/`; a
        // Benchmarks/ (or Plugins/, Snippets/, package-root) file must not be
        // judged even though it isn't Tests/Experiments/Examples either.
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator: Sendable {}",
            file: "Benchmarks/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `where-clause discriminated extension with correct shape is permitted`() {
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator where Element: Comparable {}",
            file: "Sources/X/Iterator where Element Comparable.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `member-only extension in the type's own file is permitted`() {
        // The extended type is declared elsewhere (another module, the
        // standard library, a macro expansion); this file is its own file
        // in this module.
        let source = """
            extension Iterator {
                func next() -> Element? { nil }
            }
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `generic specialisation extension keeps its arguments in the basename`() {
        // `extension Binding<Reminder>` has no `where` clause to name and a
        // generic typealias (`StoreOf<Feature>`) admits none; the verbatim
        // spelling is the own-file name. The stripped `Binding.swift` is
        // also accepted, as for any type declared elsewhere.
        let source = """
            extension Binding<Reminder> {
                func dueOn() -> Binding<Bool> { fatalError() }
            }
            """
        #expect(
            Lint.Rule.`extension file naming Tests`.findings(
                in: source,
                file: "Sources/X/Binding<Reminder>.swift"
            ).isEmpty
        )
        #expect(
            Lint.Rule.`extension file naming Tests`.findings(
                in: source,
                file: "Sources/X/Binding.swift"
            ).isEmpty
        )
        #expect(
            Lint.Rule.`extension file naming Tests`.findings(
                in: source,
                file: "Sources/X/Binding<Int>.swift"
            ).count == 1
        )
    }

    @Test
    func `conversion initializer may be owned by its input domain`() {
        let source = """
            extension Algebra.Magma {
                init(_ group: Algebra.Group<Element>) {}
            }
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/Algebra Group/Algebra.Group+Algebra.Magma.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `nested conversion owner path is preserved`() {
        let source = """
            extension Algebra.Monoid.Commutative {
                init(_ group: Algebra.Group<Element>.Abelian) {}
            }
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/Algebra Group/Algebra.Group.Abelian+Algebra.Monoid.Commutative.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `reversed name without matching conversion input is rejected`() {
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Algebra.Magma { func combine() {} }",
            file: "Sources/Algebra Group/Algebra.Group+Algebra.Magma.swift"
        )
        #expect(findings.count == 1)
    }
}

// MARK: - Edge

extension Lint.Rule.`extension file naming Tests`.Edge {
    @Test
    func `platform-conditional type with unconditional extension is NOT misclassified`() {
        // A top-level `#if os(...)` type declaration must be visible to the
        // by-hand top-level scan (IfConfigDeclSyntax descent), or the file is
        // wrongly classified as extension-only and judged against the
        // `<Base>` / ` where ` shapes it has no reason to satisfy.
        let source = """
            #if os(macOS)
            public struct Iterator {}
            #endif

            extension Iterator {
                public var count: Int { 0 }
            }
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `conditional conformance restated on a conditional extension classifies as conformance-adding`()
    {
        let source = "extension Iterator: Iterating where Element: Comparable {}"
        let matching = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator+Iterating.swift"
        )
        #expect(matching.isEmpty)

        let whereShaped = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator where Element Comparable.swift"
        )
        #expect(whereShaped.count == 1)
        if whereShaped.count == 1 {
            #expect(whereShaped[0].message.contains("+Iterating.swift"))
        }
    }

    @Test
    func `multiple conformances in one file - matching any added conformance satisfies the rule`() {
        let source = """
            extension Iterator: Iterating {}
            extension Iterator: Cursoring {}
            """
        let iterating = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator+Iterating.swift"
        )
        #expect(iterating.isEmpty)

        let cursoring = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Iterator+Cursoring.swift"
        )
        #expect(cursoring.isEmpty)
    }
}

// MARK: - Exemption (bundle-mechanism placement is out of this rule's scope;
// this rule's own out-of-surface predicates)

extension Lint.Rule.`extension file naming Tests`.Exemption {
    @Test
    func `file with a primary nominal type is 006's surface, not fired here`() {
        let source = """
            struct Iterator {}
            extension Iterator: Sendable {}
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `type nested via a top-level extension shell is still 006's surface`() {
        let source = """
            extension Outer {
                struct Inner {}
            }
            extension Outer.Inner: Sendable {}
            """
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }
}

// MARK: - Near-miss for every exemption

extension Lint.Rule.`extension file naming Tests`.`Near Miss` {
    @Test
    func `non-spec-mirroring name still fires wherever the rule is active`() {
        // No standards-layer exemption applies in a plain Sources/ fixture —
        // the shape must still be enforced.
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator: Iterating {}",
            file: "Sources/X/Iterator+NotTheRightConformance.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `non-Swift qualification of a stdlib-named protocol is not a stdlib conformance`() {
        // `Institute.Sendable` is a different protocol; only bare and
        // `Swift.`-qualified spellings resolve to the standard library.
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator: Institute.Sendable {}",
            file: "Sources/X/Iterator+Sendable.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `Tests path scope-excluded`() {
        let findings = Lint.Rule.`extension file naming Tests`.findings(
            in: "extension Iterator: Sendable {}",
            file: "Tests/X Tests/Wrong.swift"
        )
        #expect(findings.isEmpty)
    }
}

// MARK: - Self-firing

extension Lint.Rule.`extension file naming Tests`.`Self Firing` {
    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `self-firing control - a synthetic mismatch of this rule's own extension shape fires and its corrected name does not`()
    {
        let source = "extension Institute: Iterating {}"

        let mismatched = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Wrong.swift"
        )
        #expect(mismatched.count == 1)

        let corrected = Lint.Rule.`extension file naming Tests`.findings(
            in: source,
            file: "Sources/X/Institute+Iterating.swift"
        )
        #expect(corrected.isEmpty)
    }
}
