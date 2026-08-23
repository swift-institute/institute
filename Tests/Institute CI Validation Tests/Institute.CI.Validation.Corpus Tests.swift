public import Institute_Model
import Foundation
import Institute_CI_Model
import Institute_CI_Validation
import GitHub_Standard
import Testing

@testable import Institute_CI_Validation

/// The Institute-policy half of what `.github/scripts/tests/run.sh` ran:
/// every validator registered in
/// `Institute.CI.Validation.Registry` runs against the
/// real fixture corpus copied into a private temporary root, and each
/// scenario must meet the expectation its directory declares. The copy keeps
/// setup for Git-backed fixture subjects independent of other test suites.
///
/// The corpus here is the *non-owned* remainder of the retired shared
/// corpus: the nineteen GitHub-mechanics rule directories moved to
/// swift-foundations/swift-github-continuous-integration with their
/// validators; everything else — the Institute-policy directories this
/// registry owns plus the port residue with no Swift owner yet — moved
/// here. The residue is counted and named, never silently skipped.
@Suite
struct InstituteValidationCorpusTests {
    typealias Validation = Institute.CI.Validation

    /// The corpus, located from this file rather than from a working
    /// directory, so the suite behaves the same under SwiftPM, Xcode,
    /// and CI.
    static var fixtureRoot: URL {
        var url = URL(fileURLWithPath: #filePath)
        url.deleteLastPathComponent()  // → the test target directory
        return url.appendingPathComponent("Fixtures")
    }

    static var corpus: Validation.Corpus { .init(root: fixtureRoot.path) }

    /// Copy the read-only fixture data before creating the Git indexes needed
    /// by GH-IGNORE scenarios. This suite owns its setup instead of relying
    /// on another suite's execution order or mutable fixture state.
    static func withPrivateCorpus<Result>(
        _ body: (Validation.Corpus) throws -> Result
    ) throws -> Result {
        let fileManager = FileManager.default
        let root = fileManager.temporaryDirectory
            .appending(path: "institute-ci-validation-corpus-\(UUID().uuidString)")
        try fileManager.copyItem(at: fixtureRoot, to: root)
        do {
            try prepareGitignoreRepositories(in: root)
            let result = try body(.init(root: root.path))
            try fileManager.removeItem(at: root)
            return result
        } catch {
            // swift-linter:disable:next try optional
            // REASON: The original setup or assertion failure is the verdict.
            try? fileManager.removeItem(at: root)
            throw error
        }
    }

    private static func prepareGitignoreRepositories(in corpus: URL) throws {
        let fileManager = FileManager.default
        let ruleDirectories = try fileManager.contentsOfDirectory(
            at: corpus,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        .filter { $0.lastPathComponent.hasPrefix("gh-ignore-") }
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        for rule in ruleDirectories {
            for expectation in ["pass", "fail", "edge"] {
                let root = rule.appending(path: expectation)
                guard fileManager.fileExists(atPath: root.path) else { continue }
                for subject in try fileManager.contentsOfDirectory(
                    at: root,
                    includingPropertiesForKeys: [.isDirectoryKey]
                )
                where (try? subject.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                {
                    guard
                        try Institute.CI.Validation.Gitignore.git(
                            ["init", "-q", "."],
                            in: subject,
                            input: nil
                        ).status == 0
                    else { throw CocoaError(.fileWriteUnknown) }
                    guard
                        try Institute.CI.Validation.Gitignore.git(
                            ["add", "-f", "--all"],
                            in: subject,
                            input: nil
                        ).status == 0
                    else { throw CocoaError(.fileWriteUnknown) }
                }
            }
        }
    }

    /// One corpus run over the Institute registry. The engine's
    /// `Harness` is hardwired to the GitHub-mechanics registry, so this
    /// suite carries its own loop with the identical semantics: only
    /// findings for the directory's own rule count, `fail/` scenarios
    /// expect at least one, `pass/` and `edge/` expect none.
    struct Outcome {
        let rule: Validation.Rule
        let scenario: Validation.Corpus.Scenario
        let findings: [Validation.Finding]

        var isSatisfied: Bool {
            scenario.expectation == .violating ? !findings.isEmpty : findings.isEmpty
        }

        var summary: String {
            let verdict = isSatisfied ? "PASS" : "FAIL"
            return "\(verdict) \(rule) \(scenario.expectation.rawValue)/\(scenario.name)"
                + " (\(findings.count) finding(s))"
        }
    }

    static func run(in corpus: Validation.Corpus) throws -> (outcomes: [Outcome], unowned: [String])
    {
        var outcomes: [Outcome] = []
        var unowned: [String] = []
        for directory in try corpus.ruleDirectories() {
            guard
                let rule = Institute.CI.Validation.Registry
                    .rule(forCorpusDirectory: directory),
                let validator = Institute.CI.Validation.Registry
                    .validator(for: rule)
            else {
                unowned.append(directory)
                continue
            }
            for scenario in try corpus.scenarios(in: directory) {
                let findings = try validator.findings(in: scenario.subject)
                    .filter { $0.rule == rule }
                outcomes.append(Outcome(rule: rule, scenario: scenario, findings: findings))
            }
        }
        return (outcomes, unowned)
    }

    @Test func `no two validators claim the same rule`() {
        var seen: Set<Validation.Rule> = []
        for validator in Institute.CI.Validation.Registry.validators {
            for rule in validator.rules {
                #expect(!seen.contains(rule), "rule \(rule) is claimed twice")
                seen.insert(rule)
            }
        }
    }

    @Test func `every registered rule resolves back to its validator`() {
        for rule in Institute.CI.Validation.Registry.rules {
            #expect(
                Institute.CI.Validation.Registry.validator(for: rule) != nil
            )
        }
    }

    @Test func `the fixture corpus is where the suite expects it`() throws {
        let directories = try Self.corpus.ruleDirectories()
        // 50 rule directories plus `schema-correspondence`, the flat
        // scenario tree GH-REPO-063's own suite runs directly.
        // `ci-anchor-001` is the trust anchor's ladder (Q3,
        // swift-institute/.github#461); `gh-ignore-003` is the
        // deny-by-default shape rule (linter-rules#68).
        #expect(
            directories.count == 51,
            "expected the 51-directory Institute-side corpus, found \(directories.count)"
        )
    }

    @Test func `every owned scenario meets its expectation`() throws {
        try Self.withPrivateCorpus { corpus in
            let (outcomes, unowned) = try Self.run(in: corpus)
            for outcome in outcomes where !outcome.isSatisfied {
                Issue.record("\(outcome.summary)")
            }
            let allSatisfied = outcomes.allSatisfy { $0.isSatisfied }
            #expect(allSatisfied)
            // Guard against a silently empty run: a harness that checks
            // nothing passes everything.
            #expect(!outcomes.isEmpty)
            #expect(
                outcomes.contains { $0.scenario.expectation == .violating && !$0.findings.isEmpty }
            )
            // Port residue is named, not silently skipped: every directory is
            // either owned by this registry or listed as residue.
            let directories = try corpus.ruleDirectories()
            let owned = Set(
                directories.filter {
                    Institute.CI.Validation.Registry
                        .rule(forCorpusDirectory: $0) != nil
                }
            )
            #expect(owned.isDisjoint(with: Set(unowned)))
            #expect(owned.count + unowned.count == directories.count)
        }
    }
}
