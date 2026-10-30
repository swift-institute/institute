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
    struct `diagnostic message format Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
        @Suite struct `Detection scope` {}
    }
}

extension Lint.Rule.`diagnostic message format Tests` {
    /// The default fixture path is IN scope: a rule source under `Sources/`
    /// with a four-segment dotted basename.
    static func findings(
        in source: String,
        file: String = "Sources/Rules/Lint.Rule.Demo.Example.swift"
    ) -> [Diagnostic.Record] {
        let parsed = Lint.Source.parsed(from: source, file: file)
        return Lint.Rule.`diagnostic message format`.observe(parsed, .warning).findings
    }

    static func declaration(message: String) -> String {
        """
        enum Demo {
          static let message = "\(message)"
        }
        """
    }
}

extension Lint.Rule.`diagnostic message format Tests`.Unit {
    @Test
    func `a conforming message with a skill-ID citation is NOT flagged`() {
        let source = Lint.Rule.`diagnostic message format Tests`.declaration(
            message: "[try_optional] [API-ERR-001]: prefer typed throws over try?"
        )
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `every canonical citation form is accepted`() {
        // Skill rule ID, feedback-memory filename, research-doc path, the
        // `/`-chained form, and a bare `<file>.md` path — the Python's doc
        // enumerates all five as live shapes.
        for message in [
            "[api_err] [API-ERR-001]: description",
            "[no_try_optional] feedback_no_try_optional: description",
            "[typed_throws] Research/typed-throws-rationale.md: description",
            "[pattern-005b] [PATTERN-005b]/[MEM-SAFE-002]: description",
            "[typed_throws] typed-throws-rationale.md: description",
        ] {
            let source = Lint.Rule.`diagnostic message format Tests`.declaration(message: message)
            let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
            #expect(findings.isEmpty, "expected no finding for \(message)")
        }
    }

    @Test
    func `a conforming message split across a plus-chain is NOT flagged`() {
        // The live authoring shape: the literal is chained with `+` across
        // lines and the format prefix spans pieces.
        let source = """
            enum Demo {
              static let message: Swift.String =
                "[canimport_conditional] "
                + "[PATTERN-004a]: platform identity check uses canImport"
                + " on a platform-prefixed module."
            }
            """
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `a message without the leading rule-id bracket is flagged`() {
        let source = Lint.Rule.`diagnostic message format Tests`.declaration(
            message: "prefer typed throws over try?"
        )
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        let count = findings.count
        #expect(count == 1)
        if count == 1 {
            #expect(findings[0].identifier == "diagnostic message format")
            #expect(findings[0].severity == .warning)
        }
    }

    @Test
    func `a message without a citation separator colon is flagged`() {
        let source = Lint.Rule.`diagnostic message format Tests`.declaration(
            message: "[try_optional] prefer typed throws over try?"
        )
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `a colon not followed by whitespace is flagged`() {
        // `:\s` — the separator is `: `, not a bare `:` glued to the
        // description.
        let source = Lint.Rule.`diagnostic message format Tests`.declaration(
            message: "[try_optional] [API-ERR-001]:description"
        )
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `an empty citation is flagged`() {
        // `\S` — at least one non-whitespace citation character must sit
        // between the rule-id bracket and the separator.
        for message in [
            "[try_optional] : description",
            "[try_optional] ",
        ] {
            let source = Lint.Rule.`diagnostic message format Tests`.declaration(message: message)
            let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
            #expect(findings.count == 1, "expected a finding for \(message)")
        }
    }

    @Test
    func `a rule id that is not snake_case or kebab-case is flagged`() {
        // `[a-z_][\w-]*` — an uppercase first character or an embedded space
        // is outside the Python's rule-id vocabulary. The space case is the
        // sharp one: this package's own rule ids contain spaces, which is
        // exactly why its own messages use `internal let <name>Message`
        // rather than `static let message`.
        for message in [
            "[API-ERR-001] citation: description",
            "[foundation import] [ARCH-LAYER-007]: description",
            "[] citation: description",
        ] {
            let source = Lint.Rule.`diagnostic message format Tests`.declaration(message: message)
            let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
            #expect(findings.count == 1, "expected a finding for \(message)")
        }
    }

    @Test
    func `no closing bracket is flagged`() {
        let source = Lint.Rule.`diagnostic message format Tests`.declaration(
            message: "[try_optional citation: description"
        )
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `no whitespace after the rule-id bracket is flagged`() {
        // `\]\s+` — at least one whitespace character must follow.
        let source = Lint.Rule.`diagnostic message format Tests`.declaration(
            message: "[try_optional][API-ERR-001]: description"
        )
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `a malformed plus-chain message is flagged once`() {
        let source = """
            enum Demo {
              static let message =
                "prefer typed throws"
                + " over try? — see the throws pack."
            }
            """
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`diagnostic message format Tests`.`Edge Case` {
    @Test
    func `a type annotation on the declaration is still matched`() {
        let source = """
            enum Demo {
              static let message: Swift.String = "no format here at all"
            }
            """
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `access modifiers on the declaration are still matched`() {
        for modifier in ["public", "internal", "package", "@usableFromInline internal"] {
            let source = """
                enum Demo {
                  \(modifier) static let message = "no format here"
                }
                """
            let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
            #expect(findings.count == 1, "expected a finding for \(modifier)")
        }
    }

    @Test
    func `a NON-static message property is NOT matched`() {
        // The Python's MESSAGE_DECL requires `static let message`.
        let source = """
            struct Demo {
              let message = "no format here"
            }
            """
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `a static VAR message is NOT matched`() {
        let source = """
            enum Demo {
              static var message = "no format here"
            }
            """
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `a static let with a DIFFERENT name is NOT matched`() {
        let source = """
            enum Demo {
              static let diagnosticText = "no format here"
            }
            """
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `a non-literal initializer is out of the mechanical check's scope`() {
        // The Python's regex anchors on `= "`; a computed initializer never
        // matches and is skipped, not flagged.
        let source = """
            enum Demo {
              static let message = Demo.compose()
              static func compose() -> Swift.String { "" }
            }
            """
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `a chain that STARTS with a literal is checked against its leading literals`() {
        // The Python captures the leading literal chain and checks it even
        // when a non-literal tail follows; a bad prefix is still a finding.
        let source = """
            enum Demo {
              static let message = "no format here " + Demo.tail
              static let tail = ""
            }
            """
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.count == 1)
    }

    @Test
    func `a conforming prefix with a non-literal tail is NOT flagged`() {
        let source = """
            enum Demo {
              static let message = "[demo_rule] [API-ERR-001]: description " + Demo.tail
              static let tail = ""
            }
            """
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: source)
        #expect(findings.isEmpty)
    }

    @Test
    func `empty source produces no findings`() {
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(in: "")
        #expect(findings.isEmpty)
    }
}

// The Python's detection scope is `Sources/**/Lint.Rule.*.*.swift` — the
// institute's linter-rule authoring sites only. Controlled in both
// directions.
extension Lint.Rule.`diagnostic message format Tests`.`Detection scope` {
    private static let malformed = Lint.Rule.`diagnostic message format Tests`.declaration(
        message: "no format here"
    )

    // MARK: - Negative controls (out of scope → must NOT fire)

    @Test
    func `an ordinary source file is NOT in scope`() {
        for path in [
            "Sources/Rules/Helpers.swift",
            "Sources/Rules/Lint.Configuration.swift",
            "Sources/Rules/Rule.Demo.Example.swift",
        ] {
            let findings = Lint.Rule.`diagnostic message format Tests`.findings(
                in: Self.malformed,
                file: path
            )
            #expect(findings.isEmpty, "expected no finding for \(path)")
        }
    }

    @Test
    func `the namespace placeholder file is NOT in scope`() {
        // `Lint.Rule.<Module>.swift` (three dotted segments) carries the
        // namespace declaration, not a rule body.
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(
            in: Self.malformed,
            file: "Sources/Rules/Lint.Rule.Demo.swift"
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a rule file outside a Sources tree is NOT in scope`() {
        for path in [
            "Lint.Rule.Demo.Example.swift",
            "Tests/Rules Tests/Lint.Rule.Demo.Example Tests.swift",
            "Experiments/Lint.Rule.Demo.Example.swift",
        ] {
            let findings = Lint.Rule.`diagnostic message format Tests`.findings(
                in: Self.malformed,
                file: path
            )
            #expect(findings.isEmpty, "expected no finding for \(path)")
        }
    }

    @Test
    func `a hidden directory segment is NOT in scope`() {
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(
            in: Self.malformed,
            file: ".build/checkouts/dep/Sources/Rules/Lint.Rule.Demo.Example.swift"
        )
        #expect(findings.isEmpty)
    }

    // MARK: - Positive controls (in scope → must STILL fire)

    @Test
    func `a rule file with MORE than four dotted segments is in scope`() {
        // `Lint.Rule.Demo.Example.Fix.swift` — companion files match the
        // Python's glob too.
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(
            in: Self.malformed,
            file: "Sources/Rules/Lint.Rule.Demo.Example.Fix.swift"
        )
        #expect(findings.count == 1)
    }

    @Test
    func `a nested Sources tree is in scope`() {
        let findings = Lint.Rule.`diagnostic message format Tests`.findings(
            in: Self.malformed,
            file: "checkouts/some-package/Sources/Rule Pack/Lint.Rule.Demo.Example.swift"
        )
        #expect(findings.count == 1)
    }
}
