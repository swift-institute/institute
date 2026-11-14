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
import Linter
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing
import Text

@testable import Institute_Linter_Rule_Naming

extension `Lint.Rule Tests` {
    @Suite
    struct `bool public parameter Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension `Lint.Rule Tests`.`bool public parameter Tests` {
    static func findings(in source: String, file: String = "test.swift") -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`bool public parameter`.observe(parsed, .warning).findings
    }
}

extension `Lint.Rule Tests`.`bool public parameter Tests`.Unit {
    @Test
    func `public func with single Bool parameter is flagged`() {
        let source = "public func open(create: Bool) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "bool public parameter")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `func with no modifier of its own inside a public extension is flagged`() {
        // A member of a `public extension` is public API without carrying
        // the `public` keyword itself — the rule must walk up to the
        // extension's access level, not just the declaration's own.
        let source = "public extension Walker { func read(count: Bool) {} }"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `public func with two Bool parameters has two findings`() {
        let source = "public func open(create: Bool, truncate: Bool) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }

    @Test
    func `public init with Bool parameter is flagged`() {
        let source = """
            public struct Config {
                public init(verbose: Bool) {}
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `optional Bool parameter is flagged`() {
        let source = "public func read(strict: Bool?) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `Swift-qualified Bool is flagged`() {
        let source = "public func tag(value: Swift.Bool) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `open func with Bool parameter is flagged`() {
        let source = """
            public class Base {
                open func customize(reset: Bool) {}
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `multiple public functions are independently flagged`() {
        let source = """
            public func a(b: Bool) {}
            public func c(d: Bool) {}
            public func e(f: Int) {}
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 2)
    }
}

extension `Lint.Rule Tests`.`bool public parameter Tests`.`Edge Case` {
    @Test
    func `internal func with Bool parameter is NOT flagged`() {
        let source = "func open(create: Bool) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `private func with Bool parameter is NOT flagged`() {
        let source = "private func open(create: Bool) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `package func with Bool parameter is NOT flagged`() {
        let source = "package func open(create: Bool) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `closure-typed parameter with internal Bool is NOT flagged`() {
        let source = "public func update(body: (Bool) -> Void) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `non-Bool typed parameter is NOT flagged`() {
        let source = "public func tag(value: Int) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `BoolContainer (compound name) is NOT flagged here`() {
        // Compound name belongs to API-NAME-001's domain; this rule
        // checks only the literal `Bool` token.
        let source = "public func tag(value: BoolContainer) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `public function returning Bool is NOT flagged`() {
        // The rule scopes to PARAMETERS, not return types.
        let source = "public func isReady() -> Bool { false }"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `nested public function inside public type is flagged`() {
        let source = """
            public struct Config {
                public func reset(force: Bool) {}
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `tuple-typed parameter with Bool member is NOT flagged`() {
        // Tuple-typed parameters are out of mechanical scope; the user
        // would already have to think hard to land on a tuple param.
        let source = "public func tag(values: (Bool, Int)) {}"
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression Bool param inside @resultBuilder is NOT flagged`() {
        let source = """
            @resultBuilder
            public enum All {
                public static func buildExpression(_ expression: Bool) -> Bool { expression }
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildPartialBlock Bool params inside @resultBuilder is NOT flagged`() {
        let source = """
            @resultBuilder
            public enum All {
                public static func buildPartialBlock(first: Bool) -> Bool { first }
                public static func buildPartialBlock(accumulated: Bool, next: Bool) -> Bool {
                    accumulated && next
                }
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `buildExpression with Bool param OUTSIDE @resultBuilder IS flagged`() {
        let source = """
            public enum NotABuilder {
                public static func buildExpression(_ expression: Bool) -> Int { 0 }
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `non-protocol Bool-taking method inside @resultBuilder IS flagged`() {
        let source = """
            @resultBuilder
            public enum Builder {
                public static func configure(strict: Bool) {}
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

// #16 Option C ledger, Entry II.3 (DECISION 2026-07-23): wire-schema and
// named-options memberwise-init exemptions.
extension `Lint.Rule Tests`.`bool public parameter Tests`.`Edge Case` {
    @Test
    func `Decodable wire struct memberwise init Bool is NOT flagged`() {
        // The Mailgun `Recipient.activated` shape: the Bool mirrors the
        // provider's JSON schema.
        let source = """
            public struct Recipient: Sendable, Decodable, Equatable {
                public let email: EmailAddress
                public let activated: Bool
                public init(email: EmailAddress, activated: Bool) {
                    self.email = email
                    self.activated = activated
                }
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `Options struct memberwise init Bools are NOT flagged`() {
        // The iso-9945 `Kernel.File.Copy.Options` shape: the named-options
        // struct is the rule's own prescribed remedy.
        let source = """
            extension Kernel.File.Copy {
                public struct Options: Sendable {
                    public var overwrite: Bool
                    public var followSymlinks: Bool
                    public init(overwrite: Bool = false, followSymlinks: Bool = true) {
                        self.overwrite = overwrite
                        self.followSymlinks = followSymlinks
                    }
                }
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `behavioral Bool in wire struct init is still flagged`() {
        // A Bool the init consumes as logic (not assigned memberwise) is a
        // behavioral flag even inside a Decodable type.
        let source = """
            public struct Config: Decodable {
                public let mode: String
                public init(strict: Bool) {
                    self.mode = strict ? "strict" : "lenient"
                }
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `memberwise Bool init on plain public struct is NOT flagged`() {
        // The parameter mirrors a stored Bool field: the field's type is
        // the API decision, and the initializer only repeats it.
        let source = """
            public struct Walker {
                public let recursive: Bool
                public init(recursive: Bool) {
                    self.recursive = recursive
                }
            }
            """
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }
}

extension `Lint.Rule Tests` {
    /// A public `Bool` parameter a design keeps on purpose is suppressed by `disable:next` with a reason, which the
    /// rule sanctions; before swift-institute/Issues#273 it sanctioned no directive, so the line was ignored.
    @Suite struct `bool public parameter suppression Tests` {
        static let rule = Lint.Rule.`bool public parameter`

        static func suppression(_ source: Swift.String) -> Lint.Suppression {
            let tree = Parser.parse(source: source)
            return Lint.Suppression.scan(tree: tree, converter: SourceLocationConverter(fileName: "test.swift", tree: tree))
        }

        @Test func `a public Bool parameter with no directive is reported`() {
            let suppression = Self.suppression("public func open(create: Bool) {}")
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable next with a reason is sanctioned`() {
            let suppression = Self.suppression(
                """
                // swift-linter:disable:next bool public parameter
                // REASON: mirrors the platform API's flag one to one.
                public func open(create: Bool) {}
                """
            )
            #expect(suppression.suppresses(line: Text.Line.Number(3), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable line is not sanctioned`() {
            let suppression = Self.suppression(
                "public func open(create: Bool) {} // swift-linter:disable:line bool public parameter"
            )
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }
    }
}

// The witness of `ExpressibleByBooleanLiteral` takes the type the protocol fixes, so there is no enum to use instead,
// whichever way the parameter is spelled (swift-institute/Issues#274).
extension `Lint.Rule Tests`.`bool public parameter Tests`.`Edge Case` {
    @Test(arguments: [
        "extension Tristate: ExpressibleByBooleanLiteral { public init(booleanLiteral value: Bool) {} }",
        "extension Tristate: ExpressibleByBooleanLiteral { public init(booleanLiteral value: Swift.Bool) {} }",
        "extension Tristate: ExpressibleByBooleanLiteral { public init(booleanLiteral value: BooleanLiteralType) {} }",
        "extension Tristate: Swift.ExpressibleByBooleanLiteral { public init(booleanLiteral value: Bool) {} }",
        "public struct Flag: Sendable, ExpressibleByBooleanLiteral { public init(booleanLiteral value: Bool) {} }",
    ])
    func `a Boolean literal witness is NOT flagged, however its parameter is spelled`(source: String) {
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(findings.isEmpty, "\(source)")
    }

    @Test(arguments: [
        "public struct Flag { public init(booleanLiteral value: Bool) {} }",
        "extension Flag: Sendable { public init(booleanLiteral value: Bool) {} }",
        "extension Flag: ExpressibleByBooleanLiteral { public init(booleanLiteral value: Bool, strict: Bool) {} }",
        "extension Flag: ExpressibleByBooleanLiteral { public init(flag value: Bool) {} }",
    ])
    func `an initializer that is not the Boolean literal witness is still flagged`(source: String) {
        let findings = `Lint.Rule Tests`.`bool public parameter Tests`.findings(in: source)
        #expect(!findings.isEmpty, "\(source)")
    }
}
