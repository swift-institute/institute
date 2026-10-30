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
    struct `compound identifier Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`compound identifier Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`compound identifier`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`compound identifier Tests`.Unit {
    @Test
    func `func openWrite is flagged`() {
        let source = "public func openWrite() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "compound identifier")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `func walkFiles is flagged`() {
        let source = "public func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `var firstName is flagged`() {
        let source = "public var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `let lastError is flagged`() {
        let source = "public let lastError: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multi-camel name parseManifestFile is flagged`() {
        let source = "public func parseManifestFile() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple offending decls are all flagged`() {
        let source = """
            public func openWrite() {}
            public func walkFiles() {}
            public var firstName: String = ""
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 3)
    }
}

extension Lint.Rule.`compound identifier Tests`.`Edge Case` {
    @Test
    func `func open is NOT flagged`() {
        let source = "func open() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `boolean isEmpty is NOT flagged`() {
        let source = "var isEmpty: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `boolean hasValue is NOT flagged`() {
        let source = "var hasValue: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `boolean shouldRetry is NOT flagged`() {
        let source = "var shouldRetry: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stdlib idiom rawValue is NOT flagged`() {
        let source = "var rawValue: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    /// stdlib-vocabulary exemption: `allSatisfy` mirrors
    /// `Swift.Sequence.allSatisfy(_:)`. Joins flatMap / compactMap / forEach
    /// in namingCompoundSwiftNativeIdiomCitations.
    @Test
    func `stdlib idiom allSatisfy is NOT flagged`() {
        let source = "var allSatisfy: Bool = false"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SE-0517 mutableSpan computed property is NOT flagged`() {
        let source = """
            extension Buffer {
                public var mutableSpan: MutableSpan<Value> { fatalError() }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SE-0517 span computed property is NOT flagged`() {
        let source = """
            extension Buffer {
                public var span: Span<Value> { fatalError() }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `CustomStringConvertible description is NOT flagged`() {
        let source = """
            struct X: CustomStringConvertible {
                var description: String { "x" }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SE-0253 callAsFunction is NOT flagged`() {
        let source = """
            extension Adder {
                public func callAsFunction(_ x: Int) -> Int { x + 1 }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stdlib swapAt overload is NOT flagged`() {
        let source = """
            extension OutputSpan {
                public mutating func swapAt(_ a: Ordinal, _ b: Ordinal) {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stdlib storeBytes overload is NOT flagged`() {
        let source = """
            extension UnsafeMutableRawPointer {
                public func storeBytes<T>(of value: T, at offset: Ordinal, as type: T.Type) {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stdlib moveInitialize overload is NOT flagged`() {
        let source = """
            extension UnsafeMutablePointer {
                public func moveInitialize(from source: Self, count: Cardinal) {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stdlib quotientAndRemainder is NOT flagged`() {
        let source = """
            extension Ratio {
                public func quotientAndRemainder(dividingBy other: Self) -> (Self, Self) { fatalError() }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package-scoped compound remains governed`() {
        let source = "package func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `package-scoped variable remains governed`() {
        let source = "package var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `function parameter labels are NOT flagged`() {
        let source = "func read(atOffset: Int) {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        // The rule visits decl names, not parameter labels. The decl name `read`
        // is not compound. Parameter `atOffset` is exempt per scope choice.
        #expect(findings.isEmpty)
    }

    @Test
    func `single underscore name is NOT flagged`() {
        let source = "var _x: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression inside @resultBuilder enum is NOT flagged`() {
        let source = """
            @resultBuilder
            public enum Builder {
                public static func buildExpression(_ x: Int) -> [Int] { [x] }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildPartialBlock inside @resultBuilder enum is NOT flagged`() {
        let source = """
            @resultBuilder
            public enum Builder {
                public static func buildPartialBlock(first: Int) -> [Int] { [first] }
                public static func buildPartialBlock(accumulated: [Int], next: Int) -> [Int] {
                    accumulated + [next]
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression in plain extension is NOT flagged (name-only relaxation)`() {
        // Documents the name-only relaxation per the 2026-05-15
        // byte-extraction arc note. The earlier formulation required
        // `@resultBuilder` on the enclosing type; the relaxed form
        // exempts the 8 SE-0289 / SE-0348 builder method names
        // unconditionally because they're unique spec vocabulary.
        let source = """
            public enum NotABuilder {
                public static func buildExpression(_ x: Int) -> [Int] { [x] }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression in cross-file extension on @resultBuilder type is NOT flagged`() {
        // Simulates the byte-extraction arc's failure mode: the
        // `@resultBuilder` attribute lives on the primary type decl
        // in a different file; the extension here cannot see it via
        // walker. Name-only relaxation handles this case correctly.
        let source = """
            extension Builder where Element: Equatable {
                public static func buildExpression(_ x: Int) -> [Int] { [x] }
                public static func buildBlock(_ components: [Int]...) -> [Int] {
                    components.flatMap { $0 }
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-protocol compound method inside @resultBuilder IS flagged`() {
        // Regression guard: `openWrite` is NOT in the builder-method
        // allowlist, so it still fires inside `@resultBuilder` enums.
        // The name-only relaxation applies only to the 8 spec-defined
        // builder method names.
        let source = """
            @resultBuilder
            public enum Builder {
                public static func openWrite() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - Visibility scope ([API-NAME-002] amendment 2026-05-11)
    //
    // The rule governs effective public and package API. Internal,
    // fileprivate, and private declarations remain measured implementation
    // detail rather than consumer-observable naming surface.

    @Test
    func `fileprivate compound func is NOT flagged`() {
        let source = "fileprivate func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private compound func is NOT flagged`() {
        let source = "private func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `fileprivate compound var is NOT flagged`() {
        let source = "fileprivate var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private compound var is NOT flagged`() {
        let source = "private var firstName: String = \"\""
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `internal compound func is outside the consumer API scope`() {
        let source = "internal func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public compound func IS still flagged`() {
        let source = "public func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unannotated compound func defaults outside the consumer API scope`() {
        let source = "func walkFiles() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound field of fileprivate struct is NOT flagged`() {
        // Reproduces the Ownership.Transfer.Erased.Outgoing.Header
        // residual: fields with no explicit modifier inside a
        // fileprivate struct. Effective visibility is fileprivate.
        let source = """
            fileprivate struct Header {
                let destroyPayload: (Int) -> Void
                let payloadOffset: Int
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound field of private struct is NOT flagged`() {
        let source = """
            private struct Header {
                let destroyPayload: (Int) -> Void
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound method of fileprivate struct is NOT flagged`() {
        let source = """
            fileprivate struct Internal {
                func walkFiles() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound field of internal struct is outside the consumer API scope`() {
        let source = """
            internal struct Header {
                let destroyPayload: (Int) -> Void
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound field of public struct IS still flagged`() {
        let source = """
            public struct Header {
                public let destroyPayload: (Int) -> Void
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `compound member of private nested in public type is NOT flagged`() {
        // Outer is public but the inner type is private — effective
        // visibility of the field is private; rule must NOT fire.
        let source = """
            public struct Outer {
                private struct Inner {
                    let destroyPayload: (Int) -> Void
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `compound method in fileprivate extension is NOT flagged`() {
        let source = """
            fileprivate extension Existing {
                func walkFiles() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Ownership-Transfer-Erased-Outgoing-Header residual closes`() {
        // Verbatim reproduction of the Wave 2 leaf-triage residual
        // closed by Wave 3 Thread 4: a fileprivate struct nested inside
        // an extension, with let-bindings whose modifier list is empty
        // but whose effective visibility is fileprivate.
        let source = """
            extension Ownership.Transfer.Erased.Outgoing {
                @safe
                fileprivate struct Header {
                    let destroyPayload: (UnsafeMutableRawPointer, Int) -> Void
                    let payloadOffset: Int
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `SwiftSyntax visitPost override is required vocabulary`() {
        let source = """
            final class Visitor: SyntaxVisitor {
                override func visitPost(_: SourceFileSyntax) {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `ordinary visitPost declaration remains governed`() {
        let source = "public func visitPost() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // Exemption shape: [RULE-EXEMPT-2] (protocol-witness-citation-dict).
    // Protocol-required witness method names declared inside an
    // extension conforming to the corresponding protocol are exempt.
    // The dict is the citation surface; the conformance-context gate
    // ensures the same name outside the conformance still fires.

    @Test
    func `makeIterator inside Sequence conformance is exempt per RULE-EXEMPT-2`() {
        let source = """
            extension MyType: Sequence {
                func makeIterator() -> MyIterator { fatalError() }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `encodeAtomicRepresentation inside AtomicRepresentable conformance is exempt per RULE-EXEMPT-2`()
    {
        let source = """
            extension Tagged: AtomicRepresentable {
                static func encodeAtomicRepresentation(_ value: consuming Self) -> AtomicRepresentation { fatalError() }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `makeIterator outside conformance context is still flagged`() {
        let source = """
            extension MyType {
                public func makeIterator() -> MyIterator { fatalError() }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nextSpan inside Sequence Iterator Protocol conformance is exempt per RULE-EXEMPT-2`() {
        // Institute `Sequence.Iterator.\`Protocol\`` sole protocol
        // requirement — `mutating func nextSpan(maximumCount:) -> Span<Element>`.
        // The exemption fires on the name when the enclosing decl has
        // any conformance (gated via Naming.conformances). Outside a
        // conformance context, nextSpan still fires.
        let source = """
            public struct MyIterator: Sequence.Iterator.`Protocol` {
                public mutating func nextSpan(maximumCount: Cardinal) -> Swift.Span<Element> { fatalError() }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nextSpan outside any conformance context is still flagged`() {
        let source = """
            extension MyType {
                public mutating func nextSpan(maximumCount: Int) -> [Int] { [] }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - Swift-native idiom citations (name-only exemption)

    @Test
    func `underestimatedCount property is NOT flagged`() {
        // Swift.Sequence.underestimatedCount — protocol-required
        // property surfaced on institute Sequence-conforming types
        // whose iterator count is known at compile time. Name-only
        // exemption (no conformance gate) since the stdlib protocol
        // requirement is unique vocabulary.
        let source = """
            extension Cyclic.Group.Static: Sequence {
                public var underestimatedCount: Int { Self.modulus }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // MARK: - #32 six-name allowlist batch (swift-array#9 adjudication)

    @Test
    func `removeAll(keepingCapacity:) is NOT flagged`() {
        // Swift.Array.removeAll(keepingCapacity:) — front-door shadowing
        // contract [DS-028].
        let source = """
            extension MyArray {
                public mutating func removeAll(keepingCapacity: Bool = false) {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `reserveCapacity is NOT flagged`() {
        // Swift.Array.reserveCapacity(_:).
        let source = """
            extension MyArray {
                public mutating func reserveCapacity(_ n: Index<Element>.Count) {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `withSpan is NOT flagged`() {
        // Scoped-access counterpart to the already-allowlisted `span` getter.
        let source = """
            extension MyArray {
                public func withSpan<R: ~Copyable, E: Error>(_ body: (Span<Element>) throws(E) -> R) throws(E) -> R {
                    try body(span)
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `withMutableSpan is NOT flagged`() {
        // Scoped-access counterpart to the already-allowlisted `mutableSpan` getter.
        let source = """
            extension MyArray {
                public mutating func withMutableSpan<R: ~Copyable, E: Error>(
                    _ body: (inout MutableSpan<Element>) throws(E) -> R
                ) throws(E) -> R {
                    try body(&mutableSpan)
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `withElement is NOT flagged`() {
        // Stdlib withX scoped-borrow family — 8 declaring packages across
        // swift-molecules.
        let source = """
            extension MyArray {
                public func withElement<R: ~Copyable, E: Error>(
                    at index: Index<Element>, _ body: (borrowing Element) throws(E) -> R
                ) throws(E) -> R {
                    try body(storage[index])
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `freeCapacity is NOT flagged`() {
        // L1 container-family vocabulary — 4 declaring packages across
        // swift-molecules (Array, SlotMap, Queue, Queue.DoubleEnded).
        let source = """
            extension MyArray {
                public var freeCapacity: Index<Element>.Count { capacity - count }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // MARK: - Backtick-escape exemption

    @Test
    func `narrative backticked test name with internal uppercase is NOT flagged`() {
        // [SWIFT-TEST-005] canonical form for @Test functions. The
        // narrative name contains a lowercase→uppercase transition
        // (at `UInt`) that the predicate would otherwise see as
        // compound — the backtick-escape exemption short-circuits
        // before the predicate runs.
        let source = """
            @Test
            func `construction from UInt`() {}
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `narrative backticked test name with embedded API reference is NOT flagged`() {
        // Cohort precedent from swift-compositions/swift-json:
        //   func `next emits objectStart and objectEnd for empty object`()
        // The embedded `objectStart` / `objectEnd` API references carry
        // internal uppercase that pre-exemption would fire the rule.
        let source = """
            @Test
            func `next emits objectStart and objectEnd for empty object`() {}
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `backticked keyword-conflict-escape function name is NOT flagged`() {
        // `default` is a Swift keyword; the backtick escape is the
        // only way to name a function `default`. The exemption
        // makes the semantic explicit even though the predicate
        // would not have fired (no uppercase letters in `default`).
        let source = "func `default`() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `backticked var with narrative name is NOT flagged`() {
        // Parity with FunctionDecl exemption for variable bindings.
        // A property authored as `let \`current Phase index\`: Int = 0`
        // is narrative-identifier shape (per the same convention),
        // not API surface CamelCase.
        let source = "let `current Phase index`: Int = 0"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `redundant backtick on plain compound name is still exempt`() {
        // Backticks are a syntactic opt-out from standard identifier
        // conventions. If the author explicitly backtick-escapes a
        // CamelCase compound name, respect the opt-out — they had
        // a reason (the rule cannot infer intent from non-keyword,
        // non-narrative backticks). Documented as part of the
        // exemption semantics so reviewers don't get surprised.
        let source = "func `openWrite`() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `plain (un-escaped) compound name remains flagged after backtick exemption`() {
        // Regression guard: the backtick exemption MUST NOT
        // short-circuit non-backticked CamelCase names.
        let source = "public func openWrite() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested function declaration inside function body is NOT flagged`() {
        // Symmetric with the local let/var exemption: nested helper
        // functions inside test bodies (or any function body) are
        // function-scope-local and have no consumer-observable API
        // surface. Common pattern in swift-testing test bodies where
        // helpers like `readTwice` / `forkAndReadBoth` document the
        // test's setup arc.
        let source = """
            func outer() {
                func readTwice() {}
                func forkAndReadBoth() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `top-level compound function remains flagged after nested-function exemption`() {
        // Regression guard: the nested-function exemption MUST NOT
        // short-circuit top-level (or member) compound function names.
        let source = "public func openWrite() {}"
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `local compound binding inside a shorthand getter is NOT flagged`() {
        // A short-form computed-property getter (`{ ... }`, no explicit
        // `get { }`) parses as `AccessorBlockSyntax.getter` — there is no
        // `AccessorDeclSyntax` node. A local binding scoped to that body is
        // function-scope-local exactly like one inside an explicit `get { }`
        // or a plain function body, and has no consumer-observable API
        // surface.
        let source = """
            extension Buffer {
                public var summary: String {
                    let byteCount = 0
                    return "\\(byteCount)"
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested function inside a shorthand getter is NOT flagged`() {
        let source = """
            extension Buffer {
                public var value: Int {
                    func computeStuff() -> Int { 0 }
                    return computeStuff()
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `local compound binding inside a shorthand subscript getter is NOT flagged`() {
        let source = """
            extension Buffer {
                public subscript(index: Int) -> Int {
                    let rawIndex = index
                    return rawIndex
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

// #16 Option C ledger, Entry III.d (DECISION 2026-07-23): the witness
// allowlist mechanism — conformance-gated and name-only entries.
extension Lint.Rule.`compound identifier Tests`.`Edge Case` {
    @Test
    func `conformance-gated property witness inside conforming extension is NOT flagged`() {
        // The Identity.OAuth.GitHub witness-file shape (0205e7f seed).
        let source = """
            extension Identity.OAuth.GitHub: Identity.OAuth.Provider {
                public var displayName: String { "GitHub" }
                public var requiresTokenStorage: Bool { false }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `conformance-gated property witness outside conformance context is still flagged`() {
        // Same name in a bare extension with no same-file conformance: the
        // gate does not hold, the compound name fires.
        let source = """
            extension Widget {
                public var displayName: String { "w" }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `name-only method witness in per-method extension file is NOT flagged`() {
        // The one-extension-per-member convention places the witness in a
        // bare extension whose conformance lives in a sibling FILE; the
        // entry is name-only per the gate rationale.
        let source = """
            extension Identity.OAuth.GitHub {
                public func exchangeCode(_ code: String, redirectURI: String) async throws -> Identity.OAuth.TokenResponse {
                    fatalError()
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-witness compound identifier is still flagged`() {
        // Positive control: a compound name in no dict still fires.
        let source = """
            extension Widget {
                public func walkFiles() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// API-NAME-002 private-visibility exemption — extension of a same-file
// private type. Ruled swift-institute/.github#90 comment 5150641576 item 1
// (confirmed instance: compound `Codable` payload properties inside
// `extension BulkTrackJob { struct Payload { … } }` where
// `private struct BulkTrackJob` is declared earlier in the same file).
extension Lint.Rule.`compound identifier Tests`.`Edge Case` {
    @Test
    func `properties in an extension of a same-file private struct are NOT flagged`() {
        let source = """
            private struct BulkTrackJob {}

            extension BulkTrackJob {
                struct Payload: Codable, Sendable {
                    let identityId: String
                    let statusId: String
                }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `methods in an extension of a same-file private struct are NOT flagged`() {
        let source = """
            private struct Job {}

            extension Job {
                func openWrite() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension of a same-file fileprivate enum is NOT flagged`() {
        let source = """
            fileprivate enum Namespace {}

            extension Namespace {
                static func walkFiles() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension of a nested member type whose root is private is NOT flagged`() {
        let source = """
            private struct Root {
                struct Inner {}
            }

            extension Root.Inner {
                func openWrite() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // Near-miss / positive controls.
    @Test
    func `extension of a same-file internal struct is outside consumer API scope`() {
        let source = """
            struct Job {}

            extension Job {
                func openWrite() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `extension of a type not declared in this file is still flagged`() {
        let source = """
            private struct Other {}

            extension BulkTrackJob {
                public func openWrite() {}
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// Scan-scope gate — a SwiftPM manifest is build configuration, not API
// surface. Ruled swift-institute/.github#90 comment 5150641576 item 1(a).
extension Lint.Rule.`compound identifier Tests`.`Edge Case` {
    /// The manifest shape that produced the 3 confirmed findings.
    static let manifestSource = """
        // swift-tools-version: 6.3.3
        import PackageDescription

        extension String {
            public static let multipartFormCoding: Self = "MultipartFormCoding"
        }

        extension Target.Dependency {
            public static var multipartFormCoding: Self { .target(name: .multipartFormCoding) }
            public static var htmlFormCoderMultipart: Self {
                .product(name: "HTML Form Coder Multipart", package: "swift-html-form-coder")
            }
        }
        """

    @Test
    func `bare Package swift filename is out of scan scope`() {
        // Bare-filename positive control: the gate must match a path with no
        // directory component at all.
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: Self.manifestSource,
            file: "Package.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `nested Package swift path is out of scan scope`() {
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: Self.manifestSource,
            file: "Tests/Fixtures/Package.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `version-specific Package at swift manifest is out of scan scope`() {
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: Self.manifestSource,
            file: "Package@swift-6.3.swift"
        )
        #expect(findings.isEmpty)
    }

    // Both-directions controls: whole-filename matching only.
    @Test
    func `the same manifest source in an ordinary file is still flagged`() {
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: Self.manifestSource,
            file: "Sources/Core/Names.swift"
        )
        #expect(findings.count == 3)
    }

    @Test
    func `PackageInfo swift is NOT treated as a manifest`() {
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: "public func openWrite() {}",
            file: "Sources/Core/PackageInfo.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `MyPackage swift is NOT treated as a manifest`() {
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: "public func openWrite() {}",
            file: "Sources/Core/MyPackage.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `a directory segment named Package swift does NOT gate the file`() {
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: "public func openWrite() {}",
            file: "Sources/Package.swift/Names.swift"
        )
        #expect(findings.count == 1)
    }
}

// MARK: - Test-scaffolding exemption (#53)
//
// Fixtures in every direction for the `@Test` / `@Suite` exemption:
// a violation that must fire, the exempt shapes, near-misses that must
// STILL fire, and a bare-filename positive control proving the suite is
// not silenced wholesale by a path predicate.

extension Lint.Rule.`compound identifier Tests`.Unit {

    // --- Exempt: the declaration carries the attribute itself ---

    @Test
    func `compound Test function name is exempt`() {
        let source = """
            @Suite struct S {}
            extension S { @Test func deadBeefRoundTrip() {} }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `qualified Testing Test attribute is exempt`() {
        let source = """
            @Suite struct S {}
            extension S { @Testing.Test func deadBeefRoundTrip() {} }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // --- Exempt: member of a `@Suite` type ---

    @Test
    func `fixture property inside a Suite type is exempt`() {
        let source = """
            @Suite struct `Binary.Base Tests` {
                static let hexAlphabet: [UInt8] = []
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `fixture in a bare extension of a same-file Suite type is exempt`() {
        // The institute suite shape: fixtures live in a bare extension of the
        // suite, so no walk-up reaches the `@Suite` attribute. Resolved by
        // matching the extended type's LEAF against the file's `@Suite` names.
        let source = """
            extension Algebra.Law {
                @Suite struct Test {
                    @Suite struct Unit {}
                }
            }
            extension Algebra.Law.Test {
                static var intSemigroup: Int { 0 }
                static var intMonoid: Int { 0 }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    // --- Near-miss: must STILL fire ---

    @Test
    func `NEAR MISS plain helper beside a Suite in the same file still fires`() {
        // No `@Test`, not inside the suite, and the extended type's leaf is not
        // a declared suite name. This is the shape a careless file-scoped gate
        // would silence.
        let source = """
            @Suite struct `Binary.Base Tests` {}
            public struct Helper { public static var sampleBytes: Int { 0 } }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `NEAR MISS test-support library API in a Tests path still fires`() {
        // Test-support targets live under `Tests/` but ship as `.library`
        // products imported across packages — they ARE consumer API. This is
        // the case a `Tests/` PATH exemption would have wrongly silenced, and
        // is the reason the exemption is an attribute gate.
        let source = "public struct Support { public static var sampleBytes: Int { 0 } }"
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: source,
            file: "Tests/Support/Binary Base Test Support/Support.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `NEAR MISS extension of a non-suite type in a suite file still fires`() {
        let source = """
            @Suite struct Unit {}
            extension SomeProductionType.Encoder {
                public static var defaultAlphabet: Int { 0 }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `NEAR MISS resultBuilder member is not covered by the Suite exemption`() {
        let source = """
            @resultBuilder public struct B { public static var lastResult: Int { 0 } }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `NEAR MISS Suite-named type WITHOUT the attribute still fires`() {
        let source = """
            public struct Test { public static var intSemigroup: Int { 0 } }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // --- Positive control ---

    @Test
    func `POSITIVE CONTROL bare filename with no directory component fires`() {
        // Guards the whole fixture suite: if a future path-scoped predicate
        // mis-handles a path with no directory separator, every other
        // expectation in this file would silently read as a clean zero.
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: "public func openWrite() {}",
            file: "Names.swift"
        )
        #expect(findings.count == 1)
    }
}

// MARK: - #53 review follow-up (PR #56 review 4845547846)

extension Lint.Rule.`compound identifier Tests`.Unit {

    // --- The `@Test`-on-the-declaration clause, isolated ---
    //
    // The two exempt fixtures above wrap the `@Test` func in an extension of a
    // same-file `@Suite`, so the EXTENSION branch already exempts them and
    // deleting `hasAttribute(attributes, named: "Test")` left the whole suite
    // green. These two are bare top-level `@Test` functions with no suite type
    // anywhere in the file, so nothing but that clause can exempt them — they
    // fail if it is removed. Verified by deleting the clause: these two, and
    // only these two, go red.

    @Test
    func `bare top-level Test function is exempt via the attribute clause`() {
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: "@Test func deadBeefRoundTrip() {}"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `bare top-level qualified Testing Test function is exempt via the attribute clause`() {
        let findings = Lint.Rule.`compound identifier Tests`.findings(
            in: "@Testing.Test func deadBeefRoundTrip() {}"
        )
        #expect(findings.isEmpty)
    }

    // --- Known limitation: same-file suite-leaf collision ---

    @Test
    func `KNOWN LIMITATION same-file suite leaf name collides with a production type`() {
        // `suiteTypeNames(in:)` collects `@Suite` type names file-wide and matches
        // the extended type's LEAF, so a production `Measurement.Unit` extension
        // sharing a leaf with a `@Suite struct Unit` in the same file is silenced.
        //
        // This is the one clause of the exemption that fails toward SILENCE, and
        // the Institute suite leaves (`Unit`, `Test`, `EdgeCase`) are exactly the
        // collision-prone names — so it is pinned here rather than left untested.
        // Zero instances in the #53 pilot corpus. Narrowing this needs the
        // extension's full qualified path checked against the suite's nesting
        // path, not just the leaf; deliberately out of scope for #53.
        //
        // The opposite direction is safe by construction: a suite declared in a
        // SIBLING file is absent from the set, so the rule still fires.
        let source = """
            @Suite struct Unit {}
            extension Measurement.Unit {
                static var meterPerSecond: Int { 0 }
            }
            """
        let findings = Lint.Rule.`compound identifier Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
