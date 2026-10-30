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
    struct `nested tag Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`nested tag Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`nested tag`.observe(parsed, .warning).findings
    }
}

extension Lint.Rule.`nested tag Tests`.Unit {
    @Test
    func `empty enum Tag nested in enum is flagged`() {
        let source = """
            enum Order {
                enum Tag {}
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "nested tag")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `empty struct Tag nested in struct is flagged`() {
        let source = """
            struct Order {
                struct Tag {}
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `empty enum Tag nested in extension is flagged`() {
        let source = """
            extension Order {
                enum Tag {}
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `empty enum Tag nested in class is flagged`() {
        let source = """
            class Order {
                enum Tag {}
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `empty enum Tag nested in actor is flagged`() {
        let source = """
            actor Order {
                enum Tag {}
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple nested Tag in siblings are all flagged`() {
        let source = """
            enum Order {
                enum Tag {}
            }
            enum Cardinal {
                enum Tag {}
            }
            enum Ordinal {
                struct Tag {}
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.count == 3)
    }

    @Test
    func `deep-nested Tag (3 levels) is flagged`() {
        let source = """
            enum Outer {
                enum Middle {
                    enum Tag {}
                }
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        // Both the Middle.Tag (literally named Tag, nested) — and that's the only Tag.
        #expect(findings.count == 1)
    }

    @Test
    func `nested struct Tag with computed-only members is flagged`() {
        // Computed properties don't disqualify (still phantom-type-like — no storage).
        let source = """
            enum Order {
                struct Tag {
                    static var description: String { "Order" }
                }
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `nested struct Tag with only a static let is flagged`() {
        // `static let` is type-level storage, not instance storage — it must
        // not disqualify the phantom-type reading.
        let source = """
            enum Order {
                struct Tag {
                    static let raw = 1
                }
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`nested tag Tests`.`Edge Case` {
    @Test
    func `top-level enum Tag is NOT flagged`() {
        // Top-level Tag has no enclosing namespace whose role it would duplicate.
        let source = "enum Tag {}"
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `top-level struct Tag is NOT flagged`() {
        let source = "struct Tag {}"
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested enum Tag with cases is NOT flagged`() {
        // Domain Tag type (HTML.Tag-style) — has cases, not a phantom marker.
        let source = """
            enum HTML {
                enum Tag {
                    case div
                    case span
                    case p
                }
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested struct Tag with stored property is NOT flagged`() {
        // Domain Tag type — has storage, not a phantom marker.
        let source = """
            enum XML {
                struct Tag {
                    let name: String
                    let attributes: [String: String]
                }
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested type named other-than-Tag is NOT flagged`() {
        let source = """
            enum Order {
                struct Marker {}
                enum Inner {}
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested class Tag is NOT flagged`() {
        // The rule visits StructDeclSyntax / EnumDeclSyntax; classes are not
        // phantom-type carriers in the Tagged / Property API surface.
        let source = """
            enum Order {
                class Tag {}
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested suffix-Tag (OrderTag) is NOT flagged here`() {
        // Suffix-form is covered by Lint.Rule.Naming.Tag — this rule only
        // catches the literal-Tag-nested form.
        let source = """
            enum Order {
                enum OrderTag {}
            }
            """
        let findings = Lint.Rule.`nested tag Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}
