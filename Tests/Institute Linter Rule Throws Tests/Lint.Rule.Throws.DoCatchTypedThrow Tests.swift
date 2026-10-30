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
    struct `do throws for typed catch with throw Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`do throws for typed catch with throw Tests` {
    static func findings(
        in source: Swift::String,
        file: Swift::String = "test.swift"
    ) -> [Diagnostic
        .Record]
    {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`do throws for typed catch with throw`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`do throws for typed catch with throw Tests`.Unit {
    @Test
    func `bare do throw catch is flagged`() {
        let source = """
            func f() {
                do {
                    throw MyError.bar
                } catch {
                    handle(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.count == 1)
        if findings.count == 1 {
            #expect(findings[0].identifier == "do throws for typed catch with throw")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `throw nested in if is flagged`() {
        let source = """
            func f(_ cond: Bool) {
                do {
                    if cond {
                        throw MyError.bar
                    }
                } catch {
                    handle(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple bare do throw blocks all flagged`() {
        let source = """
            func f() {
                do { throw A.x } catch { handle(error) }
                do { throw B.y } catch { handle(error) }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`do throws for typed catch with throw Tests`.`Edge Case` {
    @Test
    func `typed do throw catch is NOT flagged`() {
        let source = """
            func f() {
                do throws(MyError) {
                    throw .bar
                } catch {
                    handle(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do with try (no throw) is NOT flagged - handled by DoCatchTyped`() {
        let source = """
            func f() {
                do {
                    try foo()
                } catch {
                    handle(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `do with both try and throw is NOT flagged here - DoCatchTyped covers it`() {
        let source = """
            func f() {
                do {
                    try foo()
                    throw MyError.x
                } catch {
                    handle(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    // swiftlint:disable:next function_name_whitespace
    func
        `do with throw and try only inside a nested closure is flagged - mutual exclusion with DoCatchTyped`()
    {
        // Regression guard for the DoCatchTyped/DoCatchTypedThrow mutual-
        // exclusion contract: a `try` inside a nested closure is not at
        // the `do` body's own effect scope, so this `do` has (at its own
        // scope) a `throw` and no `try` — `do throws for typed catch with
        // throw` should fire exactly once, and `do throws for typed
        // catch` (the sibling rule) should stay silent on the same site.
        let source = """
            func f() {
                do {
                    register { try handler() }
                    throw MyError.x
                } catch {
                    handle(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `do throw without catch is NOT flagged`() {
        let source = """
            func f() throws {
                do {
                    throw MyError.x
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throw alongside try optional IS flagged - try optional does not propagate`() {
        // `try?` does not propagate, so its presence should not suppress this
        // rule in favor of `DoCatchTyped` — the bare `throw` here is the only
        // thing needing a typed do-catch.
        let source = """
            func f() {
                do {
                    let x = try? maybeWork()
                    guard let x else { throw MyError.bar }
                    use(x)
                } catch {
                    handle(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `throw inside nested closure is NOT flagged at outer do`() {
        let source = """
            func f() {
                do {
                    let _ = { throw MyError.x }
                } catch {
                    handle(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `throw inside nested do is NOT counted toward outer do`() {
        let source = """
            func f() {
                do {
                    do throws(MyError) {
                        throw .x
                    } catch {
                        handle(error)
                    }
                } catch {
                    handle(error)
                }
            }
            """
        let findings = Lint.Rule.`do throws for typed catch with throw Tests`.findings(in: source)
        // Outer do has no direct throw; inner do has throw but already typed.
        // Neither should be flagged.
        #expect(findings.isEmpty)
    }
}
