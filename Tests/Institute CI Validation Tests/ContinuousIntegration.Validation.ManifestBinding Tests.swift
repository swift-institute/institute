import Foundation
import GitHub_Continuous_Integration
import GitHub_Continuous_Integration_Validation
import GitHub_Continuous_Integration_Workflow
import GitHub_Standard
import ContinuousIntegration
import Testing

@testable import Institute_CI_Validation

/// `[CI-MANIFEST-BINDING]`.
///
/// The fixture corpus under `Fixtures/ci-manifest-binding/` is
/// exercised by the corpus-runner suite, which runs every registered
/// validator over every scenario. What is here is what the corpus
/// cannot express: the two reading decisions that would each turn the
/// rule silently inert. The assertions against
/// `swift-institute/.github`'s own live manifest and its Python stub
/// trees stay with that repository until TX-APP2Z.
@Suite
struct CIValidationManifestBindingTests {
    /// The permanent exception, asserted rather than only documented.
    ///
    /// Check 2 scans for `validate-*.py`. The fixture stubs are the
    /// only reason `fail/missing-reference` can fail, so a sweep that
    /// "finished the Swift port" by deleting them would leave this
    /// rule passing on a corpus that no longer tests it. Membership is
    /// pinned **exactly**: a test whose purpose is to fail when the
    /// corpus shrinks must count.
    @Suite
    struct Integration {
        @Test func `the fixture stubs are still Python and still present`() throws {
            let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
                .appendingPathComponent("Fixtures")

            func stubs(under path: String) -> [String] {
                let root = url.appendingPathComponent(path)
                return
                    (FileManager.default
                    .enumerator(atPath: root.path)?
                    .compactMap { $0 as? String }
                    .filter { $0.hasSuffix(".py") }
                    // `FileManager.enumerator(atPath:)` yields relative
                    // paths joined with the platform's native separator —
                    // `\` on Windows. The corpus spelling this asserts is
                    // the repository-relative form, which is always
                    // `/`-joined regardless of host platform.
                    .map { $0.replacingOccurrences(of: "\\", with: "/") } ?? [])
                    .sorted()
            }

            #expect(
                stubs(under: "ci-manifest-binding") == [
                    "edge/multi-rule-same-script/.github/scripts/validate-paired.py",
                    "edge/self-firing-deferred-no-triggers/.github/scripts/validate-stub.py",
                    "fail/deprecated-non-empty/.github/scripts/validate-foo.py",
                    "fail/missing-reference/.github/scripts/validate-bar.py",
                    "fail/missing-reference/.github/scripts/validate-foo.py",
                    "fail/self-firing-active-missing-triggers/.github/scripts/validate-stub.py",
                    "pass/clean/.github/scripts/validate-foo.py",
                    "pass/self-firing-active-with-triggers/.github/scripts/validate-stub.py",
                ]
            )

            #expect(
                stubs(under: "schema-correspondence") == [
                    "fail/constant-renamed/validate-readme.py",
                    "fail/readme-exempt-unhandled/validate-readme.py",
                    "fail/readme-family-unhandled/validate-readme.py",
                    "fail/settings-key-unread/validate-readme.py",
                    "pass/consistent/validate-readme.py",
                ]
            )
        }
    }

    @Suite
    struct Unit {
        /// The YAML 1.1 recovery. A bare `on:` resolves to the boolean
        /// `true`, so a reader that only asked for the string key would
        /// find no triggers on any workflow and report every self-firing
        /// entry as broken.
        @Test func `a bare on key is reached through its boolean spelling`() throws {
            let document = try GitHub.ContinuousIntegration.Workflow.YAML.Parser.parse(
                """
                name: x
                on:
                  push:
                    branches: [main]
                  pull_request: {}
                """
            )
            let mapping = try #require(document.mapping)
            #expect(mapping["on"] == nil)
            #expect(
                ContinuousIntegration.Validation.ManifestBinding.triggerKeys(of: mapping)
                    == ["push", "pull_request"]
            )
        }

        @Test func `a quoted on key is a different key and still reads`() throws {
            let document = try GitHub.ContinuousIntegration.Workflow.YAML.Parser.parse(
                """
                "on":
                  push: {}
                """
            )
            let mapping = try #require(document.mapping)
            #expect(
                ContinuousIntegration.Validation.ManifestBinding.triggerKeys(of: mapping)
                    == ["push"]
            )
        }

        @Test func `the sequence and scalar forms of on are read too`() throws {
            let sequence = try #require(
                try GitHub.ContinuousIntegration.Workflow.YAML.Parser.parse(
                    "on: [push, pull_request]"
                ).mapping
            )
            #expect(
                ContinuousIntegration.Validation.ManifestBinding.triggerKeys(of: sequence)
                    == ["push", "pull_request"]
            )
            let scalar = try #require(
                try GitHub.ContinuousIntegration.Workflow.YAML.Parser.parse("on: push").mapping
            )
            #expect(
                ContinuousIntegration.Validation.ManifestBinding.triggerKeys(of: scalar)
                    == ["push"]
            )
        }

        /// Message text inherited from the retired corpus, and load-bearing
        /// while its counterpart still exists.
        @Test func `retired renderings match Python's repr`() {
            #expect(GitHub.ContinuousIntegration.Validation.Retired.quoted("CI-010") == "'CI-010'")
            #expect(
                GitHub.ContinuousIntegration.Validation.Retired.list(["push", "pull_request"])
                    == "['push', 'pull_request']"
            )
            #expect(GitHub.ContinuousIntegration.Validation.Retired.value(.null) == "None")
            #expect(GitHub.ContinuousIntegration.Validation.Retired.value(.boolean(true)) == "True")
            #expect(
                GitHub.ContinuousIntegration.Validation.Retired.typeName(.sequence([])) == "list"
            )
            #expect(!GitHub.ContinuousIntegration.Validation.Retired.isTruthy(.text("")))
            #expect(GitHub.ContinuousIntegration.Validation.Retired.isTruthy(.text("x")))
        }
    }

    @Suite
    struct `Edge Case` {
        /// Absence of the manifest is a *finding*, not a defect: the
        /// question "does this repository bind its validators?" was asked
        /// and answered.
        @Test func `a missing manifest is a finding and not an exit-2`() throws {
            let subject = GitHub.ContinuousIntegration.Validation.Subject(
                repository: "swift-institute-test/empty",
                root: NSTemporaryDirectory()
            )
            let findings = try ContinuousIntegration.Validation.ManifestBinding()
                .findings(in: subject)
            #expect(findings.count == 1)
            #expect(findings[0].message.hasPrefix("manifest missing:"))
        }
    }
}
