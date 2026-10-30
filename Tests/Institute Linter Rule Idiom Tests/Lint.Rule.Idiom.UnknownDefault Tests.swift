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
import Text

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    @Suite
    struct `unknown default Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`unknown default Tests` {
    static func findings(source: Swift::String) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source)
        return Lint.Rule.`unknown default`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`unknown default Tests`.Unit {
    @Test
    func `unknown default in a switch is flagged`() {
        let source = """
            func kind(of value: Value) -> Kind {
              switch value {
              case .byte: .byte
              @unknown default: .other
              }
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "unknown default")
        #expect(findings.first?.severity == .warning)
    }

    @Test
    func `explicit case handling is permitted`() {
        let source = """
            func kind(of value: Value) -> Kind {
              switch value {
              case .byte: .byte
              case .word: .word
              }
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `plain default is outside this rule`() {
        let source = """
            func kind(of value: Value) -> Kind {
              switch value {
              case .byte: .byte
              default: .other
              }
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`unknown default Tests`.`Edge Case` {
    @Test
    func `each unknown default fires once across nested switches`() {
        let source = """
            func classify(_ a: Value, _ b: Value) -> Kind {
              switch a {
              case .byte:
                switch b {
                case .byte: .byte
                @unknown default: .other
                }
              @unknown default: .other
              }
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.count == 2)
    }

    @Test
    func `unknown default inside a closure is detected`() {
        let source = """
            let kind = values.map { value in
              switch value {
              case .byte: Kind.byte
              @unknown default: Kind.other
              }
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `diagnostic is located at the attribute`() {
        let source = """
            func kind(of value: Value) -> Kind {
              switch value {
              case .byte: .byte
              @unknown default: .other
              }
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.first?.location.line == 4)
        #expect(findings.first?.location.column == 3)
    }
}

extension Lint.Rule.`unknown default Tests`.Unit {
    // #24 defect 3: `@unknown case _:` is the same runtime-fallthrough
    // shape as `@unknown default:`, spelled as a wildcard case.

    @Test
    func `unknown wildcard case is flagged`() {
        let source = """
            switch soundCategory {
            case .ambient: break
            case .playback: break
            @unknown case _:
              fatalError("unhandled category")
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.count == 1)
    }

    @Test
    func `unknown default keyword still fires alongside wildcard support`() {
        let source = """
            switch soundCategory {
            case .ambient: break
            @unknown default:
              fatalError("unhandled category")
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`unknown default Tests`.Integration {
    @Test
    func `exemption analogue - an unknown-named attribute elsewhere does not fire`() {
        let source = """
            @unknown struct Marker {}

            func kind(of value: Value) -> Kind {
              switch value {
              case .byte: .byte
              case .word: .word
              }
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `self-firing control catches the published external guidance shape`() {
        // The construct exactly as widely published external guidance
        // recommends it, which is the shape this rule exists to catch.
        let source = """
            switch soundCategory {
            case .ambient: break
            case .playback: break
            @unknown default:
              fatalError("unhandled category")
            }
            """
        let findings = Lint.Rule.`unknown default Tests`.findings(source: source)
        #expect(findings.count == 1)
    }
}
