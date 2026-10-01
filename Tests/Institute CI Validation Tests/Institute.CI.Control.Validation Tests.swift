public import Institute_Model
import Institute_CI_Model
import Institute_CI_Validation
import GitHub_Standard
import Testing

@Suite
struct `Control Validation Tests` {
    @Test
    func `canonical checker deletion is a finding`() throws {
        let root = FixtureFiles.temporaryPath(FixtureFiles.uniqueName())
        try FixtureFiles.createDirectory(root)
        defer { try? FixtureFiles.remove(root) }
        try FixtureFiles.write(bytes: Array("candidate data\n".utf8), to: FixtureFiles.join(root, "README.md"))

        let run = Institute.CI.Control.Validation.run(
            repository: "swift-institute/.github",
            root: root
        )

        #expect(run.defect == nil)
        #expect(run.findings.contains { $0.rule == "CI-CONTROL-001" })
    }

    @Test
    func `candidate remains data while floating-action positive control fires`() throws {
        let root = FixtureFiles.temporaryPath(FixtureFiles.uniqueName())
        let workflows = FixtureFiles.join(root, ".github/workflows")
        try FixtureFiles.createDirectory(workflows)
        defer { try? FixtureFiles.remove(root) }

        let workflow = """
            on:
              workflow_dispatch:
            permissions: {}
            jobs:
              probe:
                runs-on: ubuntu-latest
                steps:
                  - uses: swift-institute/.github/.github/actions/probe@main
            """
        try FixtureFiles.write(bytes: Array(workflow.utf8), to: FixtureFiles.join(workflows, "probe.yml"))
        try FixtureFiles.write(
            bytes: Array("#!/bin/sh\nexit 99\n".utf8),
            to: FixtureFiles.join(root, "candidate-code")
        )

        let run = Institute.CI.Control.Validation.run(
            repository: "swift-institute-test/control-candidate",
            root: root
        )

        #expect(run.defect == nil)
        #expect(run.findings.contains { $0.rule == "CI-117" })
        #expect(run.tsv.contains("\tCI-117\t"))
    }

    @Test
    func `canonical compositor does not retain the superseded runner label heuristic`() throws {
        let root = FixtureFiles.temporaryPath(FixtureFiles.uniqueName())
        let workflows = FixtureFiles.join(root, ".github/workflows")
        try FixtureFiles.createDirectory(workflows)
        defer { try? FixtureFiles.remove(root) }

        let universal = CIValidationUniversalWorkflowTests.workflow()
            .replacing(
                "  macos-release:\n    runs-on: ubuntu-latest",
                with: "  macos-release:\n    runs-on: xcode-27"
            )
            .replacing(
                "  apple-simulator-build:\n    runs-on: ubuntu-latest",
                with: "  apple-simulator-build:\n    runs-on: xcode-27"
            )
        try FixtureFiles.write(
            bytes: Array(universal.utf8),
            to: FixtureFiles.join(workflows, "swift-ci.yml")
        )
        let host = """
            on:
              workflow_dispatch:
                inputs:
                  repository: {required: true, type: string}
                  pull: {required: true, type: string}
                  head: {required: true, type: string}
            permissions: {}
            jobs: {}
            """
        try FixtureFiles.write(
            bytes: Array(host.utf8),
            to: FixtureFiles.join(workflows, "control-validate.yml")
        )

        let run = Institute.CI.Control.Validation.run(
            repository: "swift-institute/.github",
            root: root
        )

        #expect(
            !run.findings.contains {
                $0.message.contains("runs-on must reference a macos runner")
            }
        )
    }

    @Test
    func `unreadable candidate is unmeasured`() {
        let root = "/path/that/control-validation-does-not-have"
        let run = Institute.CI.Control.Validation.run(
            repository: "swift-institute-test/control-candidate",
            root: root
        )

        #expect(run.findings.isEmpty)
        #expect(run.defect == .unreadableSubject(root: root))
        #expect(run.exitCode == 2)
    }

    @Test
    func `empty candidate is unmeasured`() throws {
        let root = FixtureFiles.temporaryPath(FixtureFiles.uniqueName())
        try FixtureFiles.createDirectory(root)
        defer { try? FixtureFiles.remove(root) }

        let run = Institute.CI.Control.Validation.run(
            repository: "swift-institute-test/control-candidate",
            root: root
        )

        #expect(run.findings.isEmpty)
        #expect(run.defect != nil)
        #expect(run.exitCode == 2)
    }
}
