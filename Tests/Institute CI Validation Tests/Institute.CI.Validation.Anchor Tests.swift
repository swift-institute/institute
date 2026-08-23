public import Institute_Model
import Foundation
import Institute_CI_Model
import Institute_CI_Validation
import GitHub_Standard
import Institute_CI_Inventory
import Testing

@testable import Institute_CI_Validation

/// `[CI-ANCHOR-001]` — the blocking regeneration-correspondence gate.
///
/// The corpus-runner suite already asserts the coarse expectation every
/// scenario directory declares (`fail/` fires, `pass/` and `edge/` do
/// not). This suite asserts the part a directory name cannot: *which*
/// condition fired, and how many times. A gate that fails for the wrong
/// reason is indistinguishable from one that works, right up until the
/// reason it was built for happens.
@Suite
struct CIValidationAnchorTests {
    typealias Validation = Institute.CI.Validation

    static let rule: Validation.Rule = "CI-ANCHOR-001"

    static func root(_ kind: String, _ name: String) -> String {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/ci-anchor-001/\(kind)/\(name)").path
    }

    static func scenario(_ kind: String, _ name: String) -> Validation.Subject {
        .init(repository: "swift-institute-test/\(name)", root: root(kind, name))
    }

    static func findings(_ kind: String, _ name: String) throws -> [Validation.Finding] {
        try Institute.CI.Validation.Anchor()
            .findings(in: scenario(kind, name))
    }

    // MARK: - Registration

    @Test func `the rule resolves to this validator`() {
        #expect(
            Institute.CI.Validation.Registry.validator(for: Self.rule)
                is Institute.CI.Validation.Anchor
        )
    }

    @Test func `the corpus directory name resolves to the registered spelling`() {
        #expect(
            Institute.CI.Validation.Registry
                .rule(forCorpusDirectory: "ci-anchor-001") == Self.rule
        )
    }

    // MARK: - The gate's positive control

    @Test func `a workflow carrying exactly what its inputs regenerate is clean`() throws {
        #expect(try Self.findings("pass", "pinned-sources").isEmpty)
    }

    /// The narrow exemption, and the reason it is safe: it is the
    /// *manifest* that is absent. A repository claiming no anchor is not
    /// asserted to have one.
    @Test func `a repository that records no anchor is not held to one`() throws {
        #expect(try Self.findings("edge", "no-anchor-recorded").isEmpty)
    }

    // MARK: - The gate's negative controls

    /// The failure the whole design exists to catch.
    @Test func `a pin edited in the workflow is caught`() throws {
        let findings = try Self.findings("fail", "hand-edited-pin")
        #expect(findings.count == 1)
        #expect(findings.allSatisfy { $0.rule == Self.rule })
        let message = try #require(findings.first?.message)
        #expect(message.contains("Checkout swift-foundations/swift-continuous-integration"))
        #expect(message.contains("is not what the recorded trust-anchor inputs regenerate"))
    }

    /// The same divergence from the opposite cause: the inputs advanced
    /// and nobody regenerated. Both generated steps carry the old pin, so
    /// both are reported — this is the gate firing on its own subject,
    /// which is the only evidence that it can.
    @Test func `inputs that advanced without regeneration are caught`() throws {
        let findings = try Self.findings("fail", "regeneration-not-run")
        #expect(findings.count == 2)
        #expect(
            findings.allSatisfy {
                $0.message.contains("is not what the recorded trust-anchor inputs regenerate")
            }
        )
    }

    /// A pin with no identity check is a pin trusted on the fetcher's
    /// word. The two facts must both be present to be able to disagree.
    @Test func `a checkout with no identity check is caught`() throws {
        let findings = try Self.findings("fail", "identity-check-absent")
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("source identity` step") == true)
    }

    /// Order is load-bearing: the check reads the workspace, and a
    /// workspace the pinned checkout has not written yet answers about
    /// something else.
    @Test func `an identity check running before its checkout is caught`() throws {
        let findings = try Self.findings("fail", "identity-before-checkout")
        #expect(findings.contains { $0.message.contains("before") })
    }

    /// An anchor over a workflow that is not there is not a pass.
    @Test func `a recorded anchor with no workflow is caught`() throws {
        let findings = try Self.findings("fail", "workflow-absent")
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("does not exist") == true)
    }

    // MARK: - Reading decisions the corpus cannot express

    /// Fail-closed on the manifest itself: a recorded anchor that cannot
    /// be read is a finding, never an absent anchor. The two are one
    /// character apart in a JSON file and worlds apart in meaning.
    @Test func `a malformed manifest is a finding, not an absent anchor`() throws {
        let root = try Self.temporary(manifest: "{ not json", workflow: "on: {}\njobs: {}\n")
        defer { try? FileManager.default.removeItem(atPath: root) }
        let findings = try Institute.CI.Validation.Anchor()
            .findings(in: .init(repository: "swift-institute-test/malformed", root: root))
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("could not be read") == true)
    }

    /// A manifest whose pin is not a full object name is refused at the
    /// manifest, before anything is regenerated from it.
    @Test func `an abbreviated pin is refused rather than resolved`() throws {
        let manifest = """
            {
              "schema_version": 1,
              "producer": "institute-ci trust-anchor",
              "action": "actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1",
              "sources": [
                {
                  "repository": "swift-foundations/swift-continuous-integration",
                  "checkout": ".ci-sources/swift-continuous-integration",
                  "commit": "0a1b2c3",
                  "tree": { "path": ".", "oid": "1122334455667788990011223344556677889900" }
                }
              ]
            }
            """
        let root = try Self.temporary(manifest: manifest, workflow: "on: {}\njobs: {}\n")
        defer { try? FileManager.default.removeItem(atPath: root) }
        let findings = try Institute.CI.Validation.Anchor()
            .findings(in: .init(repository: "swift-institute-test/abbreviated", root: root))
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("pins nothing") == true)
    }

    /// A workflow that will not parse is a finding against this rule, not
    /// a defect and not a pass — the same decision `Subject.workflows`
    /// makes for every other rule.
    @Test func `an unparseable workflow is a finding`() throws {
        let manifest = try String(
            contentsOfFile: Self.root("pass", "pinned-sources") + "/.github/trust-anchor.json",
            encoding: .utf8
        )
        let root = try Self.temporary(manifest: manifest, workflow: "jobs:\n  - [\n")
        defer { try? FileManager.default.removeItem(atPath: root) }
        let findings = try Institute.CI.Validation.Anchor()
            .findings(in: .init(repository: "swift-institute-test/unparseable", root: root))
        #expect(!findings.isEmpty)
    }

    /// A scratch subject carrying a manifest and a workflow.
    static func temporary(manifest: String, workflow: String) throws -> String {
        let root = NSTemporaryDirectory() + "ci-anchor-001-" + UUID().uuidString
        let workflows = root + "/.github/workflows"
        try FileManager.default.createDirectory(
            atPath: workflows,
            withIntermediateDirectories: true
        )
        try manifest.write(
            toFile: root + "/.github/trust-anchor.json",
            atomically: true,
            encoding: .utf8
        )
        try workflow.write(
            toFile: workflows + "/swift-ci.yml",
            atomically: true,
            encoding: .utf8
        )
        return root
    }
}
