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
    struct `minimal type body Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`minimal type body Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`minimal type body`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`minimal type body Tests`.Unit {
    @Test
    func `method in type body is flagged`() {
        let source = """
            struct Buffer {
                var x: Int
                func append(_ value: Int) {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "minimal type body")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `computed property in type body is flagged`() {
        let source = """
            struct State {
                var raw: Int
                var isEmpty: Bool { raw == 0 }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `static member is flagged`() {
        let source = """
            struct Foo {
                var x: Int
                static let shared = Foo(x: 0)
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested struct in type body is flagged`() {
        let source = """
            struct Outer {
                var x: Int
                struct Inner {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `typealias in type body is flagged`() {
        let source = """
            struct Foo {
                var x: Int
                typealias Element = Int
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #28 test gap 3: subscript, nested class/enum/actor, nested
    // protocol, actor body, and static multi-binding/`class var` were
    // all reachable branches with no fixture reaching them.

    @Test
    func `subscript in type body is flagged`() {
        let source = """
            struct Foo {
                var x: Int
                subscript(index: Int) -> Int { index }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested class in type body is flagged`() {
        let source = """
            struct Outer {
                var x: Int
                class Inner {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested enum in type body is flagged`() {
        let source = """
            struct Outer {
                var x: Int
                enum Inner { case a }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested actor in type body is flagged`() {
        let source = """
            struct Outer {
                var x: Int
                actor Inner {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested protocol in type body is flagged`() {
        let source = """
            struct Outer {
                var x: Int
                protocol Inner {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `actor with a computed property is flagged - actor body is checked too`() {
        let source = """
            actor Outer {
                var x: Int = 0
                var doubled: Int { x * 2 }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `static member with multiple bindings is flagged`() {
        let source = """
            struct Foo {
                var x: Int
                static let a = 1, b = 2
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `class var member is flagged`() {
        let source = """
            class Foo {
                var x: Int = 0
                class var shared: Int { 0 }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending members each flagged`() {
        let source = """
            struct Foo {
                var x: Int
                func a() {}
                var computed: Int { x }
                static let shared = 0
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.`minimal type body Tests`.`Edge Case` {
    @Test
    func `stored properties and init only - NOT flagged`() {
        let source = """
            struct Buffer {
                @usableFromInline
                var storage: Storage

                @usableFromInline
                var count: Int

                @inlinable
                public init() {
                    self.storage = Storage()
                    self.count = 0
                }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `class with deinit - NOT flagged`() {
        let source = """
            class Box {
                var x: Int
                init() { self.x = 0 }
                deinit {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored property with willSet observer - NOT flagged`() {
        let source = """
            struct S {
                var x: Int {
                    willSet { print(newValue) }
                }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored property with didSet observer - NOT flagged`() {
        let source = """
            struct S {
                var x: Int {
                    didSet { print(oldValue) }
                }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `enum case is NOT flagged`() {
        let source = """
            enum E {
                case foo
                case bar
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `protocol requirements are out of scope - NOT flagged`() {
        let source = """
            protocol P {
                func op()
                var name: String { get }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `methods in extension are NOT flagged`() {
        let source = """
            struct Buffer {
                var x: Int
            }
            extension Buffer {
                func op() {}
                var doubled: Int { x * 2 }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Exemption shape: [RULE-EXEMPT-4] (@resultBuilder). Types marked
    // `@resultBuilder` carry static methods dictated by Swift's
    // `@resultBuilder` informal protocol contract per SE-0289. Forcing
    // extraction yields empty-body + extension-with-only-witnesses for
    // zero semantic gain.

    @Test
    func `@resultBuilder enum with buildBlock is exempt per RULE-EXEMPT-4`() {
        let source = """
            @resultBuilder
            enum MyBuilder {
                static func buildBlock(_ x: Int) -> Int { x }
                static func buildExpression(_ x: Int) -> Int { x }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested @resultBuilder struct is exempt per RULE-EXEMPT-4`() {
        // The nested-type's @resultBuilder attribute is checked at the
        // parent's checkMembers walk; the nested type is exempt even
        // though it's a nested type-decl, which the rule normally flags.
        let source = """
            struct Outer {
                var x: Int
                @resultBuilder
                struct InnerBuilder {
                    static func buildBlock(_ x: Int) -> Int { x }
                }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-resultBuilder struct with static method is still flagged`() {
        let source = """
            struct PlainType {
                var x: Int
                static func make() -> PlainType { PlainType(x: 0) }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Exemption shape: [RULE-EXEMPT-4] broadened to extension-pattern
    // attribute. swift-testing's `@Suite` legitimately holds nested
    // `@Suite` substructures per [SWIFT-TEST-002]; the attribute IS the
    // spec, mirroring the @resultBuilder rationale.

    @Test
    func `@Suite struct holding nested @Suite struct is exempt per RULE-EXEMPT-4`() {
        let source = """
            @Suite
            struct `Outer Suite` {
                @Suite struct Unit {}
                @Suite struct `Edge Case` {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested @Suite struct inside non-@Suite parent is exempt per RULE-EXEMPT-4`() {
        // Mirrors the existing @resultBuilder nested-type test. The
        // nested @Suite is recognized at the parent's checkMembers walk
        // and skipped without firing the nested-type-in-body branch.
        let source = """
            struct Outer {
                var x: Int
                @Suite
                struct `Inner Suite` {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-@Suite nested type inside non-@Suite parent is still flagged`() {
        // Negative case: the @Suite recognition is narrow — a plain
        // nested struct inside a plain parent still fires (no spurious
        // @Suite exemption from the broadened helper).
        let source = """
            struct Outer {
                var x: Int
                struct Helper {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Exemption shape: [RULE-EXEMPT-4] broadened to every attached
    // macro (2026-09-16). A macro-expanded body is shaped by the macro's
    // contract; the members the macro reads must sit in the body.

    @Test
    func `@Table struct with a computed column is exempt as macro-generated`() {
        let source = """
            @Table("reminders")
            struct Record {
                var title: String
                var isBlank: Bool { title.isEmpty }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `@Reducer struct nesting State and Action is exempt as macro-generated`() {
        let source = """
            @Reducer
            struct Feature {
                struct State {}
                enum Action {}
                var body: some Reducer<State, Action> { EmptyReducer() }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `module-qualified macro attribute is exempt`() {
        let source = """
            @SQLiteData.Selection
            struct Row {
                let count: Int
                var isEmpty: Bool { count == 0 }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested macro-attributed type inside a plain parent is exempt`() {
        let source = """
            struct Request {
                var limit: Int
                @Selection
                struct Counts { let all: Int }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `@MainActor is not a macro and does not exempt`() {
        let source = """
            @MainActor
            struct Screen {
                var title: String
                func present() {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `lowercase built-in attributes do not exempt`() {
        let source = """
            @frozen
            struct Value {
                var x: Int
                func read() -> Int { x }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Exemption shape: [RULE-EXEMPT-5] (Protocol-sentinel). The
    // institute hoisted-protocol pattern per [API-IMPL-009] /
    // [PKG-NAME-001] places a `typealias Protocol = _FooProtocol`
    // inside the type body intentionally; extraction yields empty-body
    // + extension-with-one-typealias for zero semantic gain.

    @Test
    func `typealias Protocol in type body is exempt per RULE-EXEMPT-5`() {
        let source = """
            enum Carrier {
                typealias Protocol = _CarrierProtocol
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias backtick-Protocol in type body is exempt per RULE-EXEMPT-5`() {
        let source = """
            enum Carrier {
                public typealias `Protocol` = Swift.Equatable
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `typealias with other name in type body is still flagged`() {
        // Negative case — the sentinel exemption is name-narrow, not a
        // typealias-blanket exemption.
        let source = """
            enum Carrier {
                typealias Underlying = SomeOtherType
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Exemption shape: [RULE-EXEMPT-7] (syntax-visitor-subclass). A
    // `final class XVisitor: SyntaxVisitor` (or `SyntaxAnyVisitor` /
    // `SyntaxRewriter`) subclass has its member shape dictated by the
    // base class's open `override func visit(_:)` / `visitPost` hooks —
    // the overrides are protocol-shaped members per the SwiftSyntax
    // visitor contract. Moving them to an extension yields
    // stored-properties + extension-of-overrides for zero semantic gain
    // (extraction measured semantic-zero across ~336 findings). The
    // carve-out keys on inheritance, not on the type name. Helper:
    // `structureExtendsSyntaxVisitor` in
    // `Lint.Rule.Structure.Shared.swift`.

    @Test
    func `SyntaxVisitor subclass with visit overrides is exempt per RULE-EXEMPT-7`() {
        let source = """
            final class MyVisitor: SyntaxVisitor {
                var matches: [Int] = []
                override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
                    return .visitChildren
                }
                override func visitPost(_ node: StructDeclSyntax) {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SyntaxRewriter subclass with visit overrides is exempt per RULE-EXEMPT-7`() {
        let source = """
            final class MyRewriter: SyntaxRewriter {
                var count: Int = 0
                override func visit(_ token: TokenSyntax) -> TokenSyntax {
                    return token
                }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SyntaxAnyVisitor subclass is exempt per RULE-EXEMPT-7`() {
        // Covers the third visitor-family base recognized by the helper.
        let source = """
            final class AnyVisitor: SyntaxAnyVisitor {
                var log: [String] = []
                override func visitAny(_ node: Syntax) -> SyntaxVisitorContinueKind {
                    return .visitChildren
                }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `qualified SwiftSyntax dot SyntaxVisitor subclass is exempt per RULE-EXEMPT-7`() {
        // Exercises the MemberTypeSyntax path of the inheritance walk:
        // the leaf-name resolution must recognize `SwiftSyntax.SyntaxVisitor`
        // the same as the bare `SyntaxVisitor` form.
        let source = """
            final class QualifiedVisitor: SwiftSyntax.SyntaxVisitor {
                override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
                    return .skipChildren
                }
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-visitor class with a method is still flagged`() {
        // Negative case — the carve-out keys on visitor-family inheritance,
        // NOT on the `Visitor` name or the presence of a `visit` method. A
        // class inheriting a non-visitor base still fires on its body method.
        let source = """
            final class FakeVisitor: NSObject {
                var x: Int = 0
                func visit() {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #28 defect 2: no `#if`-shaped fixture existed anywhere in the
    // pack, which is exactly why a hand-rolled member enumeration could
    // silently drop `#if`-guarded members.

    @Test
    func `method guarded by if os is still flagged`() {
        let source = """
            struct Foo {
                #if os(Linux)
                func f() {}
                #endif
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #28 defect 7.4: the qualified `@Testing.Suite` spelling must be
    // recognized too, matching `Shared.swift`'s handling.

    @Test
    func `qualified Testing dot Suite struct is exempt per RULE-EXEMPT-4`() {
        let source = """
            @Testing.Suite struct Foo {
                @Suite struct Unit {}
            }
            """
        let findings = Lint.Rule.`minimal type body Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
