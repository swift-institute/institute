import Lint
import Linter_Rule_Structure
import Linter_Rule_Testing
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Structure

extension Lint.Rule {

    @Suite
    struct `forbidden license header Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}

        @Test
        func `complete header produces automatic dirty to clean repair`() {
            let source = """
                // Copyright (c) 2026 Example
                // Licensed under Apache License v2.0

                struct Value {}
                """
            let parsed = Lint.Source.parsed(from: source, file: "Sources/Value.swift")
            #expect(
                Lint.Rule.`forbidden license header`.observe(parsed, .error).findings.count == 1
            )
            guard let rewritten = Lint.Rule.`forbidden license header`.rewritten(parsed) else {
                Issue.record("expected an automatic removal")
                return
            }
            let clean = Lint.Source.parsed(from: rewritten, file: "Sources/Value.swift")
            #expect(Lint.Rule.`forbidden license header`.observe(clean, .error).findings.isEmpty)
        }

        @Test
        func `partial header produces a typed repair refusal`() {
            let source = "// Licensed under Apache License v2.0\nstruct Value {}"
            let parsed = Lint.Source.parsed(from: source, file: "Sources/Value.swift")
            #expect(
                Lint.Rule.`forbidden license header`.observe(parsed, .error).findings.count == 1
            )
            guard case .refused = Lint.Rule.`forbidden license header`.repair(parsed) else {
                Issue.record("expected a typed refusal")
                return
            }
        }

        @Test
        func `ordinary leading comment is clean`() {
            let parsed = Lint.Source.parsed(
                from: "// Implementation note\nstruct Value {}",
                file: "Sources/Value.swift"
            )
            #expect(Lint.Rule.`forbidden license header`.observe(parsed, .error).findings.isEmpty)
        }
    }
}
