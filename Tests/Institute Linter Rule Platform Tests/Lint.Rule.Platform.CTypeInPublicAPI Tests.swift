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

@testable import Institute_Linter_Rule_Platform

extension Lint.Rule {
    @Suite
    struct `c type in public api Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`c type in public api Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`c type in public api`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`c type in public api Tests`.Unit {
    @Test
    func `public func with kevent parameter is flagged`() {
        let source = """
            public func register(events: [kevent]) -> Int { 0 }
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "c type in public api")
        }
    }

    @Test
    func `member of a public extension with kevent parameter is flagged`() {
        // Regression guard: a member of a `public extension` is public
        // API in Swift without carrying the keyword itself — a rule
        // scoped to public API that checks only the member's own
        // modifiers is silently defeated by moving `public` outward.
        let source = """
            public extension Reactor {
                func register(events: [kevent]) {}
            }
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with HANDLE return type is flagged`() {
        let source = """
            public func open() -> HANDLE { fatalError() }
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public init with epoll_event parameter is flagged`() {
        let source = """
            public struct Foo {
                public init(event: epoll_event) {}
            }
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // #21 defect 9: every additional shape a C type can hide in.

    @Test
    func `public func with generic member-type C type is flagged`() {
        let source = """
            public func register(pointer: Swift.UnsafePointer<kevent>) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with C type callback parameter is flagged`() {
        let source = """
            public func onEvent(_ handler: (kevent) -> Void) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with C type callback return is flagged`() {
        let source = """
            public func makeHandler() -> () -> kevent { fatalError() }
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with C type in tuple is flagged`() {
        let source = """
            public func poll() -> (Int, kevent) { fatalError() }
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with C type array element is flagged`() {
        let source = """
            public func register(events: [kevent]) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with C type dictionary key is flagged`() {
        let source = """
            public func register(table: [kevent: Int]) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with C type dictionary value is flagged`() {
        let source = """
            public func register(table: [Int: kevent]) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with C type metatype is flagged`() {
        let source = """
            public func register(type: kevent.Type) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with implicitly unwrapped optional C type is flagged`() {
        let source = """
            public func register(event: kevent!) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with any-constrained C type is flagged`() {
        let source = """
            public func register(event: any kevent) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`c type in public api Tests`.`Edge Case` {
    @Test
    func `internal func with C type is NOT flagged`() {
        let source = """
            internal func raw(event: kevent) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public func with ecosystem types is NOT flagged`() {
        let source = """
            public func register(events: [Kernel.Kqueue.Event]) {}
            """
        let findings = Lint.Rule.`c type in public api Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
