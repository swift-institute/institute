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

@testable import Institute_Linter_Rule_Architecture

extension Lint.Rule {
    @Suite
    struct `architecture namespace shape Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`architecture namespace shape Tests` {
    static func findings(
        in source: String,
        file: String = "Sources/Model Core/Model.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`architecture namespace shape`.observe(parsed, .warning).findings
    }

    @Test
    func `an instance method in a caseless enum is flagged`() {
        let source = """
            public enum Render {
              public func run() {}
            }
            """
        #expect(Self.findings(in: source).count == 1)
    }

    @Test
    func `an instance computed property in a caseless enum is flagged`() {
        let source = """
            enum Format {
              var width: Int { 80 }
            }
            """
        #expect(Self.findings(in: source).count == 1)
    }

    @Test
    func `an initializer in a caseless enum is flagged`() {
        let source = """
            enum Order {
              init() {}
            }
            """
        #expect(Self.findings(in: source).count == 1)
    }

    @Test
    func `a subscript in a caseless enum is flagged`() {
        let source = """
            enum Table {
              subscript(index: Int) -> Int { index }
            }
            """
        #expect(Self.findings(in: source).count == 1)
    }

    @Test
    func `static members in a namespace are the correct shape`() {
        let source = """
            public enum Render {
              public static let defaultWidth = 80
              public static func run() {}
              public struct Options {}
              public typealias Width = Int
            }
            """
        #expect(Self.findings(in: source).isEmpty)
    }

    @Test
    func `an enum WITH cases keeps its instance members`() {
        // Near-miss control: inhabitedness, not the name or the member, is
        // the predicate.
        let source = """
            public enum Order {
              case ascending
              case descending
              public func reversed() -> Order { self == .ascending ? .descending : .ascending }
            }
            """
        #expect(Self.findings(in: source).isEmpty)
    }

    @Test
    func `a Never-style caseless enum with a conformance clause is exempt`() {
        // Both-direction fixture for the witness-obligation carve-out: the
        // instance member is compiler-obligated by the conformance.
        let source = """
            public enum Impossible: CustomStringConvertible {
              public var description: String { "impossible" }
            }
            """
        #expect(Self.findings(in: source).isEmpty)
    }

    @Test
    func `a caseless enum nested in a cased enum is judged on its own`() {
        let source = """
            public enum Outer {
              case value
              public enum Inner {
                func hidden() {}
              }
            }
            """
        #expect(Self.findings(in: source).count == 1)
    }

    @Test
    func `a struct with instance members is out of population`() {
        let source = """
            public struct Render {
              public func run() {}
            }
            """
        #expect(Self.findings(in: source).isEmpty)
    }

    @Test
    func `every phantom instance member is reported`() {
        let source = """
            enum Namespace {
              func first() {}
              var second: Int { 2 }
              static func fine() {}
            }
            """
        #expect(Self.findings(in: source).count == 2)
    }
}
