import Lint
import Linter
import SwiftParser
import SwiftSyntax
import Testing
import Text

@testable import Institute_Linter_Rule_Try

extension Lint.Rule {
    /// A callee that throws untyped errors leaves no construct that satisfies every rule, so the rule's message tells
    /// the author to suppress the site with a reason. The rule sanctions exactly that directive
    /// (swift-molecules/swift-lint#2: a violation, an exempt and a near-miss fixture).
    @Suite struct `try optional suppression Tests` {
        static let rule = Lint.Rule.`try optional`

        static func suppression(_ source: Swift.String) -> Lint.Suppression {
            let tree = Parser.parse(source: source)
            return Lint.Suppression.scan(tree: tree, converter: SourceLocationConverter(fileName: "test.swift", tree: tree))
        }

        @Test func `an untyped site with no directive is reported`() {
            let suppression = Self.suppression("let value = try? FileManager.default.removeItem(atPath: path)")
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable next with a reason is sanctioned`() {
            let suppression = Self.suppression("""
                // swift-linter:disable:next try optional
                // REASON: FileManager.removeItem throws untyped.
                let value = try? FileManager.default.removeItem(atPath: path)
                """)
            #expect(suppression.suppresses(line: Text.Line.Number(3), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable line is not sanctioned`() {
            let suppression = Self.suppression("let value = try? FileManager.default.removeItem(atPath: path) // swift-linter:disable:line try optional")
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }
    }
}
