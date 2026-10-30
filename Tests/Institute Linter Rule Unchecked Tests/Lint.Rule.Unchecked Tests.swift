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

@testable import Institute_Linter_Rule_Unchecked

extension Lint.Rule {
    @Suite
    struct `unchecked call site Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`unchecked call site Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`unchecked call site`.observe(parsed, .warning).findings
    }

    /// Findings against a run whose brand pre-pass stamped `types`
    /// (#19 smaller item 1: the `Lint.Brand.owned` whole-run self-suppression).
    static func findings(
        in source: Swift::String,
        types: Swift::Set<Swift::String>
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, types: types)
        return Lint.Rule.`unchecked call site`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`unchecked call site Tests`.Unit {
    @Test
    func `Call site with __unchecked label is flagged`() {
        let source = "let x = Foo(__unchecked: ())"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "unchecked call site")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `Declaration site with __unchecked parameter is NOT flagged`() {
        let source = """
            struct Foo {
                init(__unchecked _: ()) {}
            }
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Other argument labels are NOT flagged`() {
        let source = "let x = Foo(name: 42, value: \"abc\")"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Multiple call sites are all flagged`() {
        let source = """
            let a = Foo(__unchecked: (), value: 1)
            let b = Bar(other: 2, __unchecked: ())
            let c = Baz(__unchecked: ())
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `Mixed declaration AND call sites flag only call sites`() {
        let source = """
            struct Foo {
                init(__unchecked _: ()) {}
            }

            let x = Foo(__unchecked: ())
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Custom severity is honored`() {
        let source = "let x = Foo(__unchecked: ())"
        let parsed = Lint.Source.parsed(from: source)
        let findings = Lint.Rule.`unchecked call site`.observe(parsed, .error).findings
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].severity == .error)
        }
    }
}

extension Lint.Rule.`unchecked call site Tests`.`Edge Case` {
    @Test
    func `Nested call site with __unchecked is flagged`() {
        let source = "let x = outer(inner: Foo(__unchecked: ()))"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Generic call site with __unchecked is flagged`() {
        let source = "let x = Foo<Int>(__unchecked: ())"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Trailing closure call with __unchecked label is flagged`() {
        let source = """
            let x = Foo(__unchecked: ()) { value in
                value + 1
            }
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `__unchecked as part of a larger label is NOT flagged`() {
        let source = "let x = Foo(__unchecked_extra: ())"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Static method call site with __unchecked is flagged`() {
        let source = "let x = Foo.make(__unchecked: ())"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `self.init call site with __unchecked is flagged`() {
        let source = """
            struct Foo {
                init(value: Int) {
                    self.init(__unchecked: ())
                }
                init(__unchecked _: ()) {}
            }
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Empty file produces no findings`() {
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }

    // MARK: - #19 smaller item 2: LabeledExprSyntax also matches tuple labels

    @Test
    func `__unchecked as a tuple element label is NOT flagged`() {
        let source = "let t = (__unchecked: value)"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `__unchecked as a call argument label is still flagged`() {
        let source = "let x = Cardinal(__unchecked: value)"
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - #19 smaller item 1: Lint.Brand.owned whole-run self-suppression

    @Test
    func `Cardinal brand-owner run self-suppresses`() {
        let findings = Lint.Rule.`unchecked call site Tests`.findings(
            in: "let x = Foo(__unchecked: ())",
            types: ["Cardinal"]
        )
        #expect(findings.isEmpty)
    }

    // MARK: - #38: the [CONV-001] extension-init bottom-out reserve

    @Test
    func `__unchecked in an extension init constructing its own type is NOT flagged`() {
        let source = """
            extension Cardinal {
                public init(validated value: Int) {
                    self.init(__unchecked: value)
                }
            }
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `__unchecked spelled Self in an extension init is NOT flagged`() {
        let source = """
            extension Lint.Cardinal {
                public init(validated value: Int) {
                    self = Self(__unchecked: value)
                }
            }
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Near-miss: an extension init that bottoms out into a DIFFERENT type is
    // an ordinary consumer bypass, not that type's own boundary.
    @Test
    func `__unchecked constructing a sibling type in an extension init is still flagged`() {
        let source = """
            extension Cardinal {
                public init(validated value: Int) {
                    self.init(offset: Ordinal(__unchecked: value))
                }
            }
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Near-miss: a closure inside the extension init is ordinary code.
    @Test
    func `__unchecked inside a closure nested in an extension init is still flagged`() {
        let source = """
            extension Cardinal {
                public init(values: [Int]) {
                    self.init(all: values.map { Cardinal(__unchecked: $0) })
                }
            }
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Near-miss: a plain function in the extension is not an initializer.
    @Test
    func `__unchecked in an extension function is still flagged`() {
        let source = """
            extension Cardinal {
                public static func make(_ value: Int) -> Cardinal {
                    Cardinal(__unchecked: value)
                }
            }
            """
        let findings = Lint.Rule.`unchecked call site Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `a non-brand-owner consumer run still fires`() {
        let findings = Lint.Rule.`unchecked call site Tests`.findings(
            in: "let x = Foo(__unchecked: ())",
            types: ["SomeConsumerType"]
        )
        #expect(findings.count == 1)
    }
}
