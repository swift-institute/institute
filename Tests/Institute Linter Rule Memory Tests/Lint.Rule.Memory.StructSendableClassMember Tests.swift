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

@testable import Institute_Linter_Rule_Memory

extension Lint.Rule {
    @Suite
    struct `sendable struct with class member Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`sendable struct with class member Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`sendable struct with class member`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`sendable struct with class member Tests`.Unit {
    @Test
    func `struct unchecked Sendable with NSObject member is flagged`() {
        let source = """
            struct Wrapper: @unchecked Sendable {
                var inner: NSObject
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "sendable struct with class member")
        }
    }

    @Test
    func `struct unchecked Sendable with same-file class member is flagged`() {
        let source = """
            final class Storage {}
            struct Box: @unchecked Sendable {
                var storage: Storage
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `struct unchecked Swift dot Sendable with same-file class member is flagged`() {
        let source = """
            final class Storage {}
            struct Box: @unchecked Swift.Sendable {
                var storage: Storage
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `struct unchecked Sendable with same-file dotted-path class member is flagged`() {
        let source = """
            enum Foo {
                final class Storage {}
            }
            struct Box: @unchecked Sendable {
                var storage: Foo.Storage
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`sendable struct with class member Tests`.`Edge Case` {
    @Test
    func `plain Sendable struct is NOT flagged`() {
        let source = """
            struct Wrapper: Sendable {
                var inner: NSObject
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct without Sendable is NOT flagged`() {
        let source = """
            struct Wrapper {
                var inner: NSObject
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct unchecked Sendable with value-typed member is NOT flagged`() {
        let source = """
            struct Wrapper: @unchecked Sendable {
                var count: Int
                var name: String
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct unchecked Sendable with struct-typed Reference-suffix member is NOT flagged`() {
        // The name-suffix heuristic ("Class"/"Reference") is deleted — a
        // struct is not a class regardless of its name.
        let source = """
            struct ValueReference {}
            struct Box: @unchecked Sendable {
                var r: ValueReference
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct unchecked Sendable with computed class-typed property is NOT flagged`() {
        let source = """
            final class Storage {}
            struct Box: @unchecked Sendable {
                var storage: Storage { Storage() }
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct unchecked Sendable with willSet-observed class-typed property is NOT flagged`() {
        // #25 nit: accessor-granularity — a willSet/didSet observer means
        // this isn't the plain stored class-typed reference shape either.
        let source = """
            final class Storage {}
            struct Box: @unchecked Sendable {
                var storage: Storage {
                    willSet { }
                }
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct unchecked Sendable with didSet-observed class-typed property is NOT flagged`() {
        let source = """
            final class Storage {}
            struct Box: @unchecked Sendable {
                var storage: Storage {
                    didSet { }
                }
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct unchecked Sendable with _read _modify class-typed property is NOT flagged`() {
        let source = """
            final class Storage {}
            struct Box: @unchecked Sendable {
                var storage: Storage {
                    _read { yield Storage() }
                    _modify { var s = Storage(); yield &s }
                }
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `struct unchecked Sendable with imported class not in the allowlist is NOT flagged`() {
        // A class declared in another module and absent from
        // `memoryStructSendableClassMemberKnownClassNames` is a real per-file
        // limit: this rule cannot resolve it.
        let source = """
            struct Box: @unchecked Sendable {
                var connection: NetworkConnection
            }
            """
        let findings = Lint.Rule.`sendable struct with class member Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
