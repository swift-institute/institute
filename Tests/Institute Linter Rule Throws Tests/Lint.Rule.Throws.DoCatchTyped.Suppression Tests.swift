import Lint
import Linter
import SwiftParser
import SwiftSyntax
import Testing
import Text

@testable import Institute_Linter_Rule_Throws

extension `Lint.Rule Tests` {
    /// A callee that throws untyped errors leaves no construct that satisfies every rule, so the rule's message tells
    /// the author to suppress the site with a reason. The rule sanctions exactly that directive
    /// (swift-molecules/swift-lint#2: a violation, an exempt and a near-miss fixture).
    @Suite struct `do throws for typed catch suppression Tests` {
        static let rule = Lint.Rule.`do throws for typed catch`

        static func suppression(_ source: Swift.String) -> Lint.Suppression {
            let tree = Parser.parse(source: source)
            return Lint.Suppression.scan(tree: tree, converter: SourceLocationConverter(fileName: "test.swift", tree: tree))
        }

        @Test func `an untyped site with no directive is reported`() {
            let suppression = Self.suppression("do { try FileManager.default.removeItem(atPath: path) } catch {}")
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable next with a reason is sanctioned`() {
            let suppression = Self.suppression(
                """
                // swift-linter:disable:next do throws for typed catch
                // REASON: FileManager.removeItem throws untyped.
                do { try FileManager.default.removeItem(atPath: path) } catch {}
                """
            )
            #expect(suppression.suppresses(line: Text.Line.Number(3), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }

        @Test func `disable line is not sanctioned`() {
            let suppression = Self.suppression("do { try FileManager.default.removeItem(atPath: path) } catch {} // swift-linter:disable:line do throws for typed catch")
            #expect(!suppression.suppresses(line: Text.Line.Number(1), rule: Self.rule.id, sanctioned: Self.rule.suppression))
        }
    }
}
