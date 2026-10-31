#if LinterRuleBuildErrors
    import Lint
    import Linter_Rules_Test_Support
    import Testing

    @testable import Institute_Linter_Rule_Build_Errors

    @Suite
    struct `build errors Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }

    extension `build errors Tests` {

        static let untyped = """
            func keys() throws -> [Int] {
              try database.read { db in
                if let pattern { return try Text.keys(matching: pattern).fetchAll(db) }
                return try Text.keys.fetchAll(db)
              }
            }
            """

        static let typed = """
            func keys() throws -> [Int] {
              try database.read { (db: SQLite.Connection) throws -> [Int] in
                if let pattern { return try Text.keys(matching: pattern).fetchAll(db) }
                return try Text.keys.fetchAll(db)
              }
            }
            """

        /// Writes `files` under a fresh root and runs the build-error bundle over `names`, as the plugin does.
        static func run(
            writing files: [Swift::String: Swift::String],
            checking names: [Swift::String],
            rules: [Lint.Rule.Configuration] = Lint.Rule.Bundle.buildErrors,
            stamp: Swift::String? = nil
        ) throws(Lint.Source.Fixture.Failure) -> Lint.Build.Outcome {
            let fixture = try Lint.Source.Fixture(files: files)
            let root = fixture.root
            let outcome = Lint.Build.run(
                arguments: ["--root", root] + (stamp.map { ["--stamp", $0] } ?? []) + names.map { root + "/" + $0 },
                rules: rules
            )
            _ = fixture.root
            return outcome
        }

        static func refusal(_ arguments: [Swift::String]) -> Lint.Build.Arguments.Error? {
            do throws(Lint.Build.Arguments.Error) {
                _ = try Lint.Build.Arguments.parse(arguments)
                return nil
            } catch {
                return error
            }
        }

        static func errors(in outcome: Lint.Build.Outcome) -> [Swift::String] {
            outcome.lines.filter { $0.contains(": error: ") }
        }
    }

    extension `build errors Tests`.Unit {

        @Test
        func `an untyped database closure fails the build with an error line`() throws {
            let outcome = try `build errors Tests`.run(
                writing: ["Sources/X/A.swift": `build errors Tests`.untyped],
                checking: ["Sources/X/A.swift"]
            )
            let errors = `build errors Tests`.errors(in: outcome)
            #expect(outcome.status == 1)
            #expect(errors.count == 1)
            #expect(errors.first?.contains("Sources/X/A.swift:2:") == true)
            #expect(errors.first?.contains(": error: [database closure type]") == true)
        }

        @Test
        func `a typed database closure passes`() throws {
            let outcome = try `build errors Tests`.run(
                writing: ["Sources/X/A.swift": `build errors Tests`.typed],
                checking: ["Sources/X/A.swift"]
            )
            #expect(outcome.status == 0)
            #expect(`build errors Tests`.errors(in: outcome).isEmpty)
        }

        @Test
        func `the last line counts files, rules and errors`() throws {
            let outcome = try `build errors Tests`.run(
                writing: ["A.swift": `build errors Tests`.untyped, "B.swift": `build errors Tests`.typed],
                checking: ["A.swift", "B.swift"]
            )
            #expect(outcome.lines.last == "swift-linter-build-errors: 2 files, 1 rules, 1 errors")
        }

        @Test
        func `findings come in path order`() throws {
            let outcome = try `build errors Tests`.run(
                writing: ["B.swift": `build errors Tests`.untyped, "A.swift": `build errors Tests`.untyped],
                checking: ["B.swift", "A.swift"]
            )
            let errors = `build errors Tests`.errors(in: outcome)
            #expect(errors.count == 2)
            #expect(errors.first?.contains("/A.swift:") == true)
            #expect(errors.last?.contains("/B.swift:") == true)
        }

        @Test
        func `arguments are the root and the files`() throws {
            let parsed = try Lint.Build.Arguments.parse(["--root", "/r", "/r/a.swift", "/r/b.swift"])
            #expect(parsed == Lint.Build.Arguments(root: "/r", files: ["/r/a.swift", "/r/b.swift"]))
        }

        @Test
        func `a stamp is read when given`() throws {
            let parsed = try Lint.Build.Arguments.parse(["--root", "/r", "--stamp", "/w/s.swift", "/r/a.swift"])
            #expect(parsed == Lint.Build.Arguments(root: "/r", files: ["/r/a.swift"], stamp: "/w/s.swift"))
        }

        @Test
        func `a stamp without a value is refused`() {
            #expect(`build errors Tests`.refusal(["--root", "/r", "/r/a.swift", "--stamp"]) == .missing(option: "--stamp"))
        }

        @Test
        func `a clean run hands back the stamp and a failed run does not`() throws {
            let clean = try `build errors Tests`.run(
                writing: ["A.swift": `build errors Tests`.typed],
                checking: ["A.swift"],
                stamp: "/w/s.swift"
            )
            #expect(clean.status == 0)
            #expect(clean.stamp == "/w/s.swift")
            let failed = try `build errors Tests`.run(
                writing: ["A.swift": `build errors Tests`.untyped],
                checking: ["A.swift"],
                stamp: "/w/s.swift"
            )
            #expect(failed.status == 1)
            #expect(failed.stamp == nil)
        }

        @Test
        func `arguments without a root are refused`() {
            #expect(`build errors Tests`.refusal(["/r/a.swift"]) == .missing(option: "--root"))
            #expect(`build errors Tests`.refusal(["/r/a.swift", "--root"]) == .missing(option: "--root"))
        }

        @Test
        func `arguments without a file are refused`() {
            #expect(`build errors Tests`.refusal(["--root", "/r"]) == .noFiles)
        }

        @Test
        func `an unknown option is refused`() {
            #expect(`build errors Tests`.refusal(["--root", "/r", "--fix", "/r/a.swift"]) == .unknown(option: "--fix"))
        }
    }

    extension `build errors Tests`.`Edge Case` {

        @Test
        func `refused arguments exit with 64 and print the usage`() {
            let outcome = Lint.Build.run(arguments: ["a.swift"], rules: Lint.Rule.Bundle.buildErrors)
            #expect(outcome.status == 64)
            #expect(outcome.lines.first?.contains("--root") == true)
            #expect(outcome.lines.last == Lint.Build.Arguments.usage)
        }

        @Test
        func `a file that cannot be read is an error, not a clean build`() throws {
            let outcome = try `build errors Tests`.run(writing: [:], checking: ["Sources/X/Missing.swift"])
            #expect(outcome.status == 1)
            #expect(
                `build errors Tests`.errors(in: outcome).contains { $0.contains("this file could not be read") }
            )
        }

        @Test
        func `a file outside the root is still checked`() throws {
            let fixture = try Lint.Source.Fixture(files: ["Sources/X/A.swift": `build errors Tests`.untyped])
            let root = fixture.root
            let outcome = Lint.Build.run(
                arguments: ["--root", root + "/Elsewhere", root + "/Sources/X/A.swift"],
                rules: Lint.Rule.Bundle.buildErrors
            )
            _ = fixture.root
            #expect(outcome.status == 1)
            #expect(`build errors Tests`.errors(in: outcome).count == 1)
        }

        @Test
        func `a disabled rule is not run`() throws {
            let disabled = Lint.Rule.Bundle.buildErrors.map { Lint.Rule.Configuration.disable($0.rule) }
            let outcome = try `build errors Tests`.run(
                writing: ["A.swift": `build errors Tests`.untyped],
                checking: ["A.swift"],
                rules: disabled
            )
            #expect(outcome.status == 0)
            #expect(outcome.lines.last == "swift-linter-build-errors: 1 files, 0 rules, 0 errors")
        }

        @Test
        func `a suppression directive does not silence a build error`() throws {
            let source = """
                // swift-linter:disable:next database closure type
                func keys() throws -> [Int] {
                  try database.read { db in
                    if let pattern { return try Text.keys(matching: pattern).fetchAll(db) }
                    return try Text.keys.fetchAll(db)
                  }
                }
                """
            let outcome = try `build errors Tests`.run(writing: ["A.swift": source], checking: ["A.swift"])
            #expect(outcome.status == 1)
        }
    }

    extension `build errors Tests`.Integration {

        @Test
        func `the bundle pins database closure type to error`() {
            let entries = Lint.Rule.Bundle.buildErrors
            #expect(entries.map { $0.rule.id.underlying } == ["database closure type"])
            #expect(entries.allSatisfy { $0.severity == .error && $0.mode == .enabled })
        }
    }
#endif
