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
    struct `do throws for typed catch Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`do throws for typed catch Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "Sources/X/Test.swift"
    )
        -> [Diagnostic.Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`do throws for typed catch`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`do throws for typed catch Tests`.Unit {
    @Test
    func `bare do try catch is flagged`() {
        let source = """
            func f() {
                do {
                    try x()
                } catch {
                    print(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `do throws(E) try catch is permitted`() {
        let source = """
            func f() {
                do throws(MyError) {
                    try x()
                } catch {
                    print(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do without try is not flagged`() {
        let source = """
            func f() {
                do {
                    let x = 1
                    _ = x
                } catch {}
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do without catch is not flagged`() {
        let source = """
            func f() {
                do {
                    try x()
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `try inside a nested closure does NOT count as the do body's own try`() {
        // Regression guard: a `try` inside a nested closure is not at the
        // `do` body's own effect scope. Without the closure skip, this
        // false-positives here AND `do throws for typed catch with throw`
        // also fires (its finder correctly skips closures), producing two
        // diagnostics on a site meant to be mutually exclusive.
        let source = """
            func f() {
                do {
                    register { try handler() }
                    throw MyError.x
                } catch {
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`do throws for typed catch Tests`.`Edge Case` {
    @Test
    func `nested do-catch tracked independently`() {
        // Outer do has no direct `try` (the inner do scopes its own try),
        // so the outer is not flagged. Inner is already typed.
        let source = """
            func f() {
                do {
                    do throws(MyError) {
                        try x()
                    } catch {
                        print(error)
                    }
                } catch {
                    print(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `outer do flagged when it contains a direct try plus an inner typed do`() {
        let source = """
            func f() {
                do {
                    try y()
                    do throws(MyError) {
                        try x()
                    } catch {}
                } catch {}
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `do with only try optional is NOT flagged`() {
        // `try?` does not propagate out of the do body, so the do-catch does
        // not need a typed-throws specifier on its account.
        let source = """
            func f() {
                do {
                    let x = try? work()
                    _ = x
                } catch {
                    print(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do with only try force is NOT flagged`() {
        let source = """
            func f() {
                do {
                    let x = try! work()
                    _ = x
                } catch {
                    print(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do with unguarded try nested inside try optional IS flagged`() {
        let source = """
            func f() {
                do {
                    let x = try? outer(try inner())
                    _ = x
                } catch {
                    print(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `top-level do try catch is flagged`() {
        let source = """
            do {
                try x()
            } catch {}
            """
        let findings = Lint.Rule.`do throws for typed catch Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}
