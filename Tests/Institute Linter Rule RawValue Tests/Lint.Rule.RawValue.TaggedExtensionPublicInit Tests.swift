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

@testable import Institute_Linter_Rule_RawValue

extension Lint.Rule {
    @Suite
    struct `tagged extension public init Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`tagged extension public init Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`tagged extension public init`.observe(parsed, .warning).findings
    }

    /// Findings against a run whose brand pre-pass stamped `types`
    /// (#23 finding 21: `Lint.Brand.owned` whole-run self-suppression).
    static func findings(
        in source: Swift::String,
        types: Swift::Set<Swift::String>
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(
            from: source,
            file: "Sources/X/Test.swift",
            types: types
        )
        return Lint.Rule.`tagged extension public init`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`tagged extension public init Tests`.Unit {
    @Test
    func `extension on bare Tagged with public init is flagged`() {
        let source = """
            extension Tagged {
                public init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "tagged extension public init")
        }
    }

    @Test
    func `extension on Tagged generic specialization with public init is flagged`() {
        // swiftlint:disable no_tag_suffix_phantom
        // REASON: `UserTag` here is fixture prose inside a string-literal source
        // sample exercising the generic-specialization surface, not a live phantom-tag
        // declaration; the regex-based no_tag_suffix_phantom rule cannot distinguish
        // fixture text from real code (rule-exemptions skill). Re-enabled immediately
        // after the fixture string.
        let source = """
            extension Tagged<UserTag, String> {
                public init(_ s: String) { fatalError() }
            }
            """
        // swiftlint:enable no_tag_suffix_phantom
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on Tagged with internal init is permitted`() {
        let source = """
            extension Tagged {
                init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on non-Tagged type with public init is permitted`() {
        let source = """
            extension MyType {
                public init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Tagged with multiple public inits flags each`() {
        let source = """
            extension Tagged {
                public init(_ s: String) { fatalError() }
                public init(value: Int) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `extension on Tagged with public method but no public init is permitted`() {
        let source = """
            extension Tagged {
                public func foo() {}
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`tagged extension public init Tests`.`Edge Case` {
    @Test
    func `extension on qualified Tagging Tagged is flagged`() {
        let source = """
            extension Tagging.Tagged {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on Tagged with where clause not binding Underlying is flagged`() {
        // `Tagged`'s real second generic parameter is `Underlying`, not
        // `RawValue` — a fixture using the fictional name `RawValue` would
        // pass for the wrong reason (it never matches `Underlying` at all,
        // by construction) rather than because a where clause alone
        // doesn't exempt. This binds a real-but-unrelated conformance
        // requirement, leaving `Underlying` unbound.
        let source = """
            extension Tagged where Tag: Hashable {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `extension on TaggedFoo (compound name) is not flagged`() {
        let source = """
            extension TaggedFoo {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: [RULE-EXEMPT-2] (protocol-witness-citation-dict).
    // Extensions on `Tagged` that conform to a stdlib literal protocol
    // are exempt — the protocol's `init(...)` requirement IS the
    // validation gate; the conformer cannot drop the public init and
    // still satisfy the contract. The dict pairs each witness key with
    // its specific protocol.

    @Test
    func
        `extension on Tagged conforming to ExpressibleByIntegerLiteral is exempt per RULE-EXEMPT-2`()
    {
        let source = """
            extension Tagged: ExpressibleByIntegerLiteral {
                public init(integerLiteral value: Int) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Tagged conforming to Decodable is exempt per RULE-EXEMPT-2`() {
        let source = """
            extension Tagged: Decodable {
                public init(from decoder: any Decoder) throws { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Tagged conforming to RawRepresentable is exempt per RULE-EXEMPT-2`() {
        let source = """
            extension Tagged: RawRepresentable {
                public init?(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: [RULE-EXEMPT-5] (Protocol-sentinel) composed
    // with [RULE-EXEMPT-2]. The `` `Protocol` `` key in the dict
    // encodes the institute hoisted-protocol pattern per [API-IMPL-009]
    // / [PKG-NAME-001]: `extension Tagged: Carrier.\`Protocol\`` —
    // the conformer satisfies the nested-namespace protocol witness
    // and inherits its init contract. The backtick-escaped form is
    // load-bearing: bare `Carrier.Protocol` parses as a
    // `MetatypeTypeSyntax` (Swift's `.Protocol` metatype keyword),
    // so the institute pattern always uses the escaped spelling.
    // Inheritance-leaf walking captures the trailing identifier as
    // `` `Protocol` ``, which matches the dict entry.

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `extension on Tagged conforming to backtick-escaped Protocol sentinel is exempt per RULE-EXEMPT-5`()
    {
        let source = """
            extension Tagged: Carrier.`Protocol` {
                public init(value: Int) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Tagged conforming to non-witness protocol is still flagged`() {
        let source = """
            extension Tagged: CustomStringConvertible {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `free-generic-Tag domain extension with Underlying binding is admitted`() {
        let source = """
            extension Tagged where Underlying == Cardinal, Tag: ~Copyable {
                public init(_ uint: UInt) { fatalError() }
                public init(_ int: Int) throws(Cardinal.Error) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        // Free generic Tag has no specific owner at which a per-tag
        // validation gate could live. The Underlying binding (==
        // Cardinal) signals "domain extension on Underlying axis",
        // which the institute uses for typed bridges between
        // numerics-domain primitives. Tag-specific invariants are out
        // of scope by construction.
        #expect(findings.isEmpty)
    }

    @Test
    func `free-generic-Tag domain extension with Underlying binding (single init) is admitted`() {
        let source = """
            extension Tagged where Underlying == Cardinal, Tag: ~Copyable {
                public init(_ index: Tagged<Tag, Ordinal>) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension binding both Underlying and Tag is still flagged (Tag bound)`() {
        let source = """
            extension Tagged where Underlying == Cardinal, Tag == MySpecificTag {
                public init(_ raw: Cardinal) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        // Tag is bound to a concrete (MySpecificTag) so a per-tag
        // validation gate IS expressible here — the rule's intent
        // applies and the init should still fire.
        #expect(findings.count == 1)
    }

    @Test
    func `where clause binding Tag but not Underlying is still flagged`() {
        // Regression guard for a stale doc/fixture: `Tagged`'s real second
        // generic parameter is `Underlying`, not `RawValue`. Binding only
        // `Tag` (a real parameter) — not `Underlying` — must NOT trip the
        // free-generic-Tag domain-extension admit, which requires
        // `Underlying` bound and `Tag` free.
        let source = """
            extension Tagged where Tag == String {
                public init(_ s: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public extension with init lacking its own modifier is flagged`() {
        // A `public extension` makes every member public by default
        // unless the member carries its own narrower modifier — the init
        // here has no modifier of its own but is still effectively public.
        let source = """
            public extension Tagged {
                init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public extension with explicitly internal init is NOT flagged`() {
        let source = """
            public extension Tagged {
                internal init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `extension whose generic-argument content mentions Tagged is not treated as extending Tagged`()
    {
        // Structural regression guard: a textual split on `.` misidentifies
        // `Dictionary<String, Foo.Tagged<A, B>>` as an extension "on"
        // `Tagged` because its last textual dot-segment reads
        // `Tagged<A, B>>`. The extended type here is `Dictionary`, not
        // `Tagged`, and must not be flagged.
        let source = """
            extension Dictionary<String, Foo.Tagged<A, B>> {
                public init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `bare extension on Tagged with no where clause is still flagged`() {
        let source = """
            extension Tagged {
                public init(raw: RawValue) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(in: source)
        // No Underlying binding signals no domain intent. Both axes
        // are free generically, but the absence of Underlying ==
        // signals this is not a deliberate domain bridge — the rule
        // should still fire to surface the bypass.
        #expect(findings.count == 1)
    }

    @Test
    func `Cardinal brand-owner run self-suppresses`() {
        let source = """
            extension Tagged {
                public init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(
            in: source,
            types: ["Cardinal"]
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a non-brand-owner consumer run still fires`() {
        let source = """
            extension Tagged {
                public init(rawValue: String) { fatalError() }
            }
            """
        let findings = Lint.Rule.`tagged extension public init Tests`.findings(
            in: source,
            types: ["SomeConsumerType"]
        )
        #expect(findings.count == 1)
    }
}
