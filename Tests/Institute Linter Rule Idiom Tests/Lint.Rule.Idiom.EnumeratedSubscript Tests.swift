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

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `enumerated with subscript Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`enumerated with subscript Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`enumerated with subscript`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`enumerated with subscript Tests`.Unit {
    @Test
    func `enumerated subscript pattern is flagged`() {
        let source = """
            func op(components: Path.Components) {
                for (i, _) in components.enumerated() {
                    use(components[i])
                }
            }
            """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "enumerated with subscript")
        }
    }

    // #24 defect 10: the receiver comparison is now structural, so
    // `self.buffer` and `buffer` are recognized as the same receiver.

    @Test
    func `self-qualified receiver matches unqualified subscript receiver`() {
        let source = """
            struct Reader {
                var buffer: [Byte]
                mutating func scan() {
                    for (i, _) in self.buffer.enumerated() {
                        use(buffer[i])
                    }
                }
            }
            """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unqualified receiver matches self-qualified subscript receiver`() {
        let source = """
            struct Reader {
                var buffer: [Byte]
                mutating func scan() {
                    for (i, _) in buffer.enumerated() {
                        use(self.buffer[i])
                    }
                }
            }
            """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `interior trivia in the receiver does not defeat the match`() {
        let source = """
            func op(components: Path  .  Components) {
                for (i, _) in components  .  enumerated() {
                    use(components[i])
                }
            }
            """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`enumerated with subscript Tests`.`Edge Case` {
    @Test
    func `enumerated without subscript-by-i is NOT flagged`() {
        let source = """
            func op(items: [Int]) {
                for (i, e) in items.enumerated() {
                    use(i, e)
                }
            }
            """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `subscript by different identifier is NOT flagged`() {
        let source = """
            func op(items: [Int], j: Int) {
                for (i, _) in items.enumerated() {
                    use(items[j])
                }
            }
            """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `forEach without enumerated is NOT flagged`() {
        let source = """
            func op(items: [Int]) {
                items.forEach { use($0) }
            }
            """
        let findings = Lint.Rule.`enumerated with subscript Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
