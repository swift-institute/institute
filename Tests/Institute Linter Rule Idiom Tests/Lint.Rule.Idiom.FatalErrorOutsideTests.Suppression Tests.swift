import Lint
import Linter
import SwiftParser
import SwiftSyntax
import Testing
import Text

@testable import Institute_Linter_Rule_Idiom

extension Lint.Rule {
    /// A built-in constant that cannot be made unrepresentable (the SDK has no URL literal) and that a test covers may
    /// trap, suppressed with a reason; the rule sanctions exactly that directive (#245; swift-molecules/swift-lint#2:
    /// a violation, an exempt and a near-miss fixture).
    @Suite struct `fatal error outside tests suppression Tests` {
        static let rule = Lint.Rule.`fatal error outside tests`

        static func suppression(_ source: Swift.String) -> Lint.Suppression {
            let tree = Parser.parse(source: source)
            return Lint.Suppression.scan(tree: tree, converter: SourceLocationConverter(fileName: "test.swift", tree: tree))
        }

        @Test func `an untyped site with no directive is reported`() {
            let suppression = Self.suppression("guard let url = make() else { fatalError() }")
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable next with a reason is sanctioned`() {
            let suppression = Self.suppression(
                """
                // swift-linter:disable:next fatal error outside tests
                // REASON: a built-in URL literal; License Tests covers it.
                guard let url = make() else { fatalError() }
                """
            )
            #expect(suppression.suppresses(line: Text.Line.Number(3), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable line is not sanctioned`() {
            let suppression = Self.suppression("guard let url = make() else { fatalError() } // swift-linter:disable:line fatal error outside tests")
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }
    }
}
