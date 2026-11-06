import Lint
import Linter
import SwiftParser
import SwiftSyntax
import Testing
import Text

@testable import Institute_Linter_Rule_Throws

extension `Lint.Rule Tests` {
    /// A declaration that hands its body to a callee taking an untyped-throwing closure cannot name a typed error, so
    /// the author suppresses the site with a reason. The rule sanctions exactly that directive, as
    /// `do throws for typed catch` does (#238; swift-molecules/swift-lint#2: a violation, an exempt and a near-miss
    /// fixture).
    @Suite struct `untyped throws suppression Tests` {
        static let rule = Lint.Rule.`untyped throws`

        static func suppression(_ source: Swift.String) -> Lint.Suppression {
            let tree = Parser.parse(source: source)
            return Lint.Suppression.scan(tree: tree, converter: SourceLocationConverter(fileName: "test.swift", tree: tree))
        }

        @Test func `an untyped declaration with no directive is reported`() {
            let suppression = Self.suppression("func apply(_ database: Database) throws {}")
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable next with a reason is sanctioned`() {
            let suppression = Self.suppression(
                """
                // swift-linter:disable:next untyped throws
                // REASON: the database's synchronous write takes an untyped closure.
                func apply(_ database: Database) throws {}
                """
            )
            #expect(suppression.suppresses(line: Text.Line.Number(3), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable line is not sanctioned`() {
            let suppression = Self.suppression("func apply(_ database: Database) throws {} // swift-linter:disable:line untyped throws")
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }
    }
}
