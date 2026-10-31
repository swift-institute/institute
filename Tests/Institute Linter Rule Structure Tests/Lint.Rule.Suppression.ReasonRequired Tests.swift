import Lint
import Linter_Rules_Test_Support
import SwiftParser
import SwiftSyntax
import Testing

@testable import Institute_Linter_Rule_Structure


@Suite
struct `suppression reason required Tests` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
    @Suite struct Integration {}
    @Test
    func `disable next with prose is permitted`() {
        let source = """
            // swift-linter:disable:next malformed suppression directive
            // REASON: the fixture intentionally exercises the suppression channel
            let value = compute()
            """
        let parsed = Lint.Source.parsed(from: source, file: "/Sources/X/File.swift")
        let findings = Lint.Rule.`suppression reason required`.observe(parsed, .error).findings
        #expect(findings.isEmpty)
    }

    @Test
    func `disable line with prose is permitted`() {
        let source = """
            let value = compute() // swift-linter:disable:line malformed suppression directive
            // REASON: the line is a controlled fixture
            """
        let parsed = Lint.Source.parsed(from: source, file: "/Sources/X/File.swift")
        let findings = Lint.Rule.`suppression reason required`.observe(parsed, .error).findings
        #expect(findings.isEmpty)
    }

    @Test
    func `reasonless next and line are flagged`() {
        let source = """
            // swift-linter:disable:next malformed suppression directive
            let first = compute()
            let second = compute() // swift-linter:disable:line malformed suppression directive
            """
        let parsed = Lint.Source.parsed(from: source, file: "/Sources/X/File.swift")
        let findings = Lint.Rule.`suppression reason required`.observe(parsed, .error).findings
        #expect(findings.count == 2)
    }

    @Test
    func `whitespace-only reason is flagged`() {
        let source = """
            // swift-linter:disable:next malformed suppression directive
            // REASON:    \t
            let value = compute()
            """
        let parsed = Lint.Source.parsed(from: source, file: "/Sources/X/File.swift")
        let findings = Lint.Rule.`suppression reason required`.observe(parsed, .error).findings
        #expect(findings.count == 1)
    }

    @Test
    func `intervening code or a blank line breaks reason association`() {
        let source = """
            // swift-linter:disable:next malformed suppression directive
            let first = compute()
            // REASON: this later prose is not associated
            // swift-linter:disable:next malformed suppression directive

            // REASON: this later prose is not associated either
            let second = compute()
            """
        let parsed = Lint.Source.parsed(from: source, file: "/Sources/X/File.swift")
        let findings = Lint.Rule.`suppression reason required`.observe(parsed, .error).findings
        #expect(findings.count == 2)
    }

    @Test
    func `a later reason cannot repair an empty immediate reason`() {
        let source = """
            // swift-linter:disable:next malformed suppression directive
            // REASON:\(String(repeating: " ", count: 3))
            // REASON: later prose does not override the empty continuation
            let value = compute()
            """
        let parsed = Lint.Source.parsed(from: source, file: "/Sources/X/File.swift")
        let findings = Lint.Rule.`suppression reason required`.observe(parsed, .error).findings
        #expect(findings.count == 1)
    }

    @Test
    func `reasonless suppression targeting this rule self-fires`() {
        let source = """
            // swift-linter:disable:next suppression reason required
            let value = compute()
            """
        let parsed = Lint.Source.parsed(from: source, file: "/Sources/X/File.swift")
        let findings = Lint.Rule.`suppression reason required`.observe(parsed, .error).findings
        #expect(findings.count == 1)
        #expect(findings.first?.identifier == "suppression reason required")
    }
}
