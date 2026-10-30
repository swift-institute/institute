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
    struct `throwing wrapper init Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`throwing wrapper init Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`throwing wrapper init`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`throwing wrapper init Tests`.Unit {
    @Test
    func `throwing init with single let-binding try-only body is flagged`() {
        // Regression guard: `self.x = try Base(...)` fired but the
        // equally unvalidated `let base = try Base(raw)` did not — no
        // stated rationale distinguished the two forwarding shapes.
        let source = """
            struct NonEmpty {
                init(_ raw: [Int]) throws {
                    let base = try Base(raw)
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throwing init with try-only body is flagged`() {
        let source = """
            struct NonEmpty {
                init(_ raw: [Int]) throws {
                    try self.base = Base(raw)
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "throwing wrapper init")
        }
    }
}

extension Lint.Rule.`throwing wrapper init Tests`.`Edge Case` {
    @Test
    func `throwing init with additional validation is NOT flagged`() {
        let source = """
            struct NonEmpty {
                init(_ raw: [Int]) throws {
                    guard !raw.isEmpty else { throw Error.empty }
                    try self.base = Base(raw)
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single-try body calling an unrelated lowercase function is NOT flagged`() {
        // Regression guard: the predicate previously fired on ANY single
        // `try` statement, not specifically a forward to the base type's
        // own initializer. `try validate(x)` is a throwing helper-function
        // call, not a construction of a base value — it is not evidence
        // the wrapper's stricter invariant goes unvalidated (it may BE
        // the validation).
        let source = """
            struct NonEmpty {
                init(_ raw: [Int]) throws {
                    try validate(raw)
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `single-try body calling a method (not a constructor) is NOT flagged`() {
        let source = """
            struct Wrapper {
                init(from decoder: Decoder) throws {
                    try self.load(from: decoder)
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-throwing init is NOT flagged`() {
        let source = """
            struct Wrapper {
                init(_ raw: [Int]) {
                    self.base = raw
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on Int with throwing init from institute type is admitted`() {
        let source = """
            extension Int {
                public init<Tag: ~Copyable>(_ position: Tagged<Tag, Ordinal>) throws(Ordinal.Error) {
                    self = try Int(position.underlying)
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        // Int is the LAX type; the rule's "wrapper specializes stricter
        // invariant" premise is inverted when the enclosing type is the
        // lax primitive and the parameter is the stricter institute
        // type. The body's overflow check IS the validation.
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on module-qualified Swift dot Int with throwing init is admitted`() {
        // #28 test gap 3: the MemberTypeSyntax arm of
        // isInsideExtensionOnLaxType (`ext.extendedType.as(MemberTypeSyntax
        // .self)`) was previously unreachable from any fixture — only the
        // bare-identifier `Int`/`UInt` shape above was covered.
        let source = """
            extension Swift.Int {
                public init<Tag: ~Copyable>(_ position: Tagged<Tag, Ordinal>) throws(Ordinal.Error) {
                    self = try Int(position.underlying)
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension on UInt with throwing init is admitted`() {
        let source = """
            extension UInt {
                public init<Tag: ~Copyable>(_ position: Tagged<Tag, Cardinal>) throws(Cardinal.Error) {
                    self = try UInt(position.underlying)
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throwing init on institute wrapper struct is still flagged`() {
        let source = """
            struct Wrapper {
                init(_ raw: Int) throws {
                    try self.init(base: raw)
                }
            }
            """
        let findings = Lint.Rule.`throwing wrapper init Tests`.findings(in: source)
        // Institute wrapper struct (not on the lax allowlist) — the
        // rule's premise applies and the init should still fire.
        #expect(findings.count == 1)
    }
}
