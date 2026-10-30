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
    struct `wrapper backing exposed Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`wrapper backing exposed Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`wrapper backing exposed`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`wrapper backing exposed Tests`.Unit {
    @Test
    func `default-internal _backing in struct is flagged`() {
        let source = """
            public struct Lane {
                let _backing: IO.Blocking.Lane
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "wrapper backing exposed")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `explicit internal _wrapped in actor is flagged`() {
        let source = """
            public actor Box {
                internal var _wrapped: Underlying
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `package _underlying in class is flagged`() {
        let source = """
            class Wrapper {
                package var _underlying: Storage
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`wrapper backing exposed Tests`.`Edge Case` {
    @Test
    func `private _backing is NOT flagged`() {
        let source = """
            struct Lane {
                private let _backing: IO.Blocking.Lane
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `fileprivate _wrapped is NOT flagged`() {
        let source = """
            struct Wrapper {
                fileprivate var _wrapped: Underlying
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private(set) _backing is flagged`() {
        // `private(set)` narrows only the setter — the getter remains at
        // the declaration's own access level, which is exactly the
        // reach-through this rule exists to prevent.
        let source = """
            struct Lane {
                private(set) var _backing: IO.Blocking.Lane
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `fileprivate(set) _wrapped is flagged`() {
        let source = """
            struct Wrapper {
                fileprivate(set) var _wrapped: Underlying
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `usableFromInline _backing is NOT flagged`() {
        let source = """
            public struct Lane {
                @usableFromInline
                var _backing: IO.Blocking.Lane
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-tracked underscore name is NOT flagged`() {
        let source = """
            struct S {
                var _other: Int
                var _internal: String
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `_backing at file scope is NOT flagged`() {
        let source = """
            let _backing = 0
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `_backing in protocol is NOT flagged`() {
        // Protocols declare requirements; backing-property convention
        // does not apply to protocol requirements.
        let source = """
            protocol P {
                var _backing: Underlying { get }
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-tracked names like backing without underscore are NOT flagged`() {
        let source = """
            struct S {
                var backing: Underlying
                var wrapped: Other
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // #28 defect 5: enum bodies and extension-declared backings were
    // previously invisible.

    @Test
    func `backing property declared in an extension is flagged`() {
        let source = """
            extension Lane {
                public var _backing: Int { 0 }
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `backing property declared in an enum is flagged`() {
        let source = """
            enum Lane {
                public static var _backing = 0
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #28 test gap 3: multi-binding and the `break` semantics that
    // limits a multi-binding var decl to a single finding.

    @Test
    func `multi-binding var with tracked name first is flagged once`() {
        let source = """
            struct Wrapper {
                var _backing: Int = 0, other: Int = 0
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func
        `multi-binding var with tracked name second is still flagged once - break does not skip later bindings`()
    {
        let source = """
            struct Wrapper {
                var other: Int = 0, _backing: Int = 0
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func
        `multi-binding var with two tracked names still fires once per decl - not once per binding`()
    {
        // The `break` after the first tracked binding stops scanning the
        // REST of this decl's bindings — one finding per var decl, not
        // one per tracked binding within it.
        let source = """
            struct Wrapper {
                var _backing: Int = 0, _wrapped: Int = 0
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #28 test gap 4 (remaining half): no #if-shaped fixture existed
    // anywhere in the pack. This rule visits VariableDeclSyntax via
    // normal recursive descent (unlike MinimalTypeBody's manual member
    // enumeration), so a #if-guarded backing property is reachable
    // without any additional code — this fixture is the regression
    // pin for that fact.
    @Test
    func `backing property guarded by if os is still flagged`() {
        let source = """
            struct Wrapper {
                #if os(Linux)
                var _backing: Int = 0
                #endif
            }
            """
        let findings = Lint.Rule.`wrapper backing exposed Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
