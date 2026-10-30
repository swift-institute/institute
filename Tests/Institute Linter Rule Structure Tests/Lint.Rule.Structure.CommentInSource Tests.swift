import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Structure

extension Lint.Rule {
    @Suite
    struct `comment in source Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`comment in source Tests` {
    static func findings(
        _ source: Swift::String,
        file: Swift::String = "Sources/Fixture/Fixture.swift"
    ) -> [Diagnostic.Record] {
        Lint.Rule.`comment in source`
            .observe(Lint.Source.parsed(from: source, file: file), .warning)
            .findings
    }
}

extension Lint.Rule.`comment in source Tests`.Unit {
    @Test
    func `line and block comments are each flagged and documentation comments are not`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            """
            // Note
            /// A value.
            /* block */
            struct Value {
                let count = 1 // trailing
                /** documentation block */
                let name = ""
            }
            """
        )
        #expect(findings.count == 3)
        #expect(findings[0].message.hasPrefix("[comment in source] [SOURCE-NO-COMMENTS]:"))
    }

    @Test
    func `the disclosure markers the skills require are admitted`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            """
            // SAFETY: Allocated once and never mutated.
            nonisolated(unsafe) let sentinel = 0
            // WHY: Category D — compiler workaround.
            // WHEN TO REMOVE: When structural inference lands.
            // TRACKING: swift-institute/Issues#1
            extension Container: @unchecked Sendable {}
            struct Storage {
                // WHY: The C API takes a raw pointer.
                // REMOVE-WHEN: The compiler accepts a span here.
                let pointer: UnsafeRawPointer
                let count = 1 // SAFETY: never negative
            }
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `a marker's continuation lines are admitted`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            """
            // SAFETY: The pointer is allocated once
            //   and freed only in deinit.
            @safe struct Storage {}
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `code without comments is clean`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            "struct Value {\n    let count = 1\n}"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`comment in source Tests`.`Edge Case` {
    @Test
    func `swift-linter directives are admitted`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            """
            // swift-linter:disable:next comment in source
            let value = 1 // swift-linter:disable:this some rule
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `comment markers inside string literals are not comments`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            """
            let a = "// not a comment"
            let b = \"\"\"
                /// still text
                \"\"\"
            """
        )
        #expect(findings.isEmpty)
    }

    @Test
    func `near misses of the markers are still flagged`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            """
            // Safety: lower case is not the marker
            // NOTE: not a marker
            // see SAFETY: not at the start
            /* SAFETY: a block comment is not the marker */
            struct Value {}
            """
        )
        #expect(findings.count == 4)
    }

    @Test
    func `a comment after a blank line is not a continuation`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            """
            // SAFETY: Allocated once.

            // A detached note.
            struct Value {}
            """
        )
        #expect(findings.count == 1)
    }

    @Test
    func `tests are out of scope`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            "// note\nstruct Value {}",
            file: "Tests/Fixture Tests/Fixture Tests.swift"
        )
        #expect(findings.isEmpty)
    }
}

extension Lint.Rule.`comment in source Tests`.Integration {
    @Test
    func `a license header is flagged line by line`() {
        let findings = Lint.Rule.`comment in source Tests`.findings(
            """
            // Copyright (c) 2026 Example
            // Licensed under Apache License v2.0

            struct Value {}
            """,
            file: "/workspace/swift-fixture/Sources/Fixture/Value.swift"
        )
        #expect(findings.count == 2)
    }
}

extension Lint.Rule.`comment in source Tests`.Integration {
    static func repaired(_ source: Swift::String) -> Swift::String? {
        let proposal = Lint.Rule.`comment in source`.repair(
            Lint.Source.parsed(from: source, file: "Sources/Fixture/Fixture.swift")
        )
        guard case .edits(let edits) = proposal, case .rewrite(_, let contents) = edits.first else {
            return nil
        }
        return contents
    }

    @Test
    func `repair removes whole-line and trailing comments and keeps documentation and markers`() {
        let repaired = Self.repaired(
            """
            // Header
            import Lint

            /// A value.
            struct Value {
                /// The count.
                let count = 1 // trailing
                /* block */
                let name = ""
                // SAFETY: Never mutated.
                let pointer: UnsafeRawPointer
            }
            """
        )
        #expect(
            repaired == """
                import Lint

                /// A value.
                struct Value {
                    /// The count.
                    let count = 1
                    let name = ""
                    // SAFETY: Never mutated.
                    let pointer: UnsafeRawPointer
                }
                """
        )
    }

    @Test
    func `repair keeps swift-linter directives`() {
        let source = "// swift-linter:disable:next some rule\nlet value = 1"
        #expect(Lint.Rule.`comment in source`.repair(Lint.Source.parsed(from: source, file: "Sources/Fixture/Fixture.swift")) == .unchanged)
    }

    @Test
    func `repaired source is clean`() {
        let repaired = Self.repaired("/// Doc\nfunc f() {} // note\n")
        #expect(repaired.map { Lint.Rule.`comment in source Tests`.findings($0).isEmpty } == true)
    }
}

extension Lint.Rule.`comment in source Tests`.Integration {
    @Test
    func `repair keeps the reason line of a suppression directive`() {
        let repaired = Self.repaired(
            """
            func f() async {
                // swift-linter:disable:next do throws for typed catch
                // REASON: Task.sleep throws untyped
                try? await Task.sleep(for: .seconds(1)) // trailing
            }
            """
        )
        #expect(
            repaired == """
                func f() async {
                    // swift-linter:disable:next do throws for typed catch
                    // REASON: Task.sleep throws untyped
                    try? await Task.sleep(for: .seconds(1))
                }
                """
        )
    }
}
