import File_System
import Testing

@testable import Institute_Model
@testable import Institute_Inventory
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Lint
@testable import Institute_Pages
@testable import Institute_Doctor
@testable import Institute_Conversion
@testable import Institute_Instruments

extension Institute.Lint.Fix {
    @Suite struct Test {}
}

extension Institute.Lint.Fix.Test {
    @Test
    func `a shadow excludes only its unsafe canonical fixer`() {
        let arguments = Institute.Lint.Fix.exclusionArguments([
            Institute.Lint.Fix.shadowedStandardLibraryQualification
        ])

        #expect(arguments == ["--fix-excluding", "PLAT-ARCH-022"])
        #expect(!arguments.contains("IMPL-033"))
    }

    @Test
    func `exclusion arguments preserve repeated and unknown engine identifiers`() {
        let arguments = Institute.Lint.Fix.exclusionArguments([
            "PLAT-ARCH-022", "SAFE-001", "PLAT-ARCH-022", "UNKNOWN-999",
        ])

        #expect(arguments == [
            "--fix-excluding", "PLAT-ARCH-022",
            "--fix-excluding", "SAFE-001",
            "--fix-excluding", "PLAT-ARCH-022",
            "--fix-excluding", "UNKNOWN-999",
        ])
    }

    /// The runner-path counterpart of the option spelling: same
    /// identifiers, same order, same duplicates, JSON-encoded for the
    /// environment channel the runner reads. The option spelling cannot
    /// reach the runner — its argument vector is lint targets only — and
    /// the channel cannot reach a command-line fix run, which ignores it.
    @Test
    func `the exclusion channel preserves repeated and unknown engine identifiers`() {
        #expect(Institute.Lint.Fix.exclusionsVariable == "SWIFT_LINTER_FIX_EXCLUDING_RULES")
        #expect(
            Institute.Lint.Fix.exclusions([
                "PLAT-ARCH-022", "SAFE-001", "PLAT-ARCH-022", "UNKNOWN-999",
            ]) == "[\"PLAT-ARCH-022\",\"SAFE-001\",\"PLAT-ARCH-022\",\"UNKNOWN-999\"]"
        )
    }

    @Test
    func `declared roots use the linter fix channel without losing order or spaces`() {
        let roots = [
            File.Directory("/fixture/package/Sources/Library"),
            File.Directory("/fixture/package/Tests/Library Tests"),
        ]

        #expect(Institute.Lint.Fix.targetsVariable == "SWIFT_LINTER_FIX_TARGETS")
        #expect(
            Institute.Lint.Fix.targets(roots)
                == "[\"/fixture/package/Sources/Library\",\"/fixture/package/Tests/Library Tests\"]"
        )
    }
}
