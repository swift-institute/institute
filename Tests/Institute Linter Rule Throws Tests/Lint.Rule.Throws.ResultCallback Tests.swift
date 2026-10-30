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

@testable import Institute_Linter_Rule_Throws

extension Lint.Rule {
    @Suite
    struct `callback result over throws thunk Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`callback result over throws thunk Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`callback result over throws thunk`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`callback result over throws thunk Tests`.Unit {
    @Test
    func `closure parameter taking Result is flagged`() {
        let source = """
            public struct API {
                public init(callback: (Result<Int, MyError>) -> Void) {}
            }
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "callback result over throws thunk")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `function parameter as closure taking Result is flagged`() {
        let source = """
            func register(_ callback: @escaping (Result<Data, IOError>) -> Bool) {}
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `stored property of closure-of-Result type is flagged`() {
        let source = """
            struct S {
                let onTick: (Result<Int, Error>) -> Void
            }
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `qualified Swift dot Result is flagged`() {
        let source = """
            func op(callback: (Swift.Result<Int, MyError>) -> Void) {}
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`callback result over throws thunk Tests`.`Edge Case` {
    @Test
    func `function returning Result is NOT flagged`() {
        let source = """
            func op() -> Result<Int, MyError> {
                .success(0)
            }
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `stored property of Result type alone is NOT flagged`() {
        let source = """
            struct S {
                let cached: Result<Int, MyError>
            }
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `top-level function parameter typed Result is NOT flagged`() {
        let source = """
            func process(_ outcome: Result<Int, MyError>) {}
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throws thunk closure parameter is NOT flagged`() {
        let source = """
            func op(_ wait: () throws(MyError) -> Int) {}
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested closure type carrying Result is flagged`() {
        let source = """
            let f: ((Result<Int, MyError>) -> Void) -> Void = { _ in }
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        // The inner closure (Result<...>) -> Void is one flag; the outer
        // takes a closure (not Result) so no second flag.
        #expect(findings.count == 1)
    }

    @Test
    func `optional closure of Result is flagged`() {
        let source = """
            struct S {
                let onTick: ((Result<Int, Error>) -> Void)?
            }
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    // MARK: - #19 smaller item 6: arity guard and container recursion

    @Test
    func `project-local non-generic Result type does NOT fire`() {
        let source = """
            enum Result { case ok, failed }
            func register(_ callback: @escaping (Result) -> Void) {}
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `array of Result closure parameter is flagged`() {
        let source = """
            func register(_ callback: @escaping ([Result<Int, MyError>]) -> Void) {}
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `tuple containing Result closure parameter is flagged`() {
        let source = """
            func register(_ callback: @escaping ((Result<Int, MyError>, Int)) -> Void) {}
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `dictionary value of Result closure parameter is flagged`() {
        let source = """
            func register(_ callback: @escaping ([String: Result<Int, MyError>]) -> Void) {}
            """
        let findings = Lint.Rule.`callback result over throws thunk Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
