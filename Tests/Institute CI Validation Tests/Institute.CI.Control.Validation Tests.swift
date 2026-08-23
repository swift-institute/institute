public import Institute_Model
import Foundation
import Institute_CI_Model
import Institute_CI_Validation
import GitHub_Standard
import Testing

@Suite
struct `Control Validation Tests` {
    @Test
    func `canonical checker deletion is a finding`() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try Data("candidate data\n".utf8).write(to: root.appendingPathComponent("README.md"))

        let run = Institute.CI.Control.Validation.run(
            repository: "swift-institute/.github",
            root: root.path
        )

        #expect(run.defect == nil)
        #expect(run.findings.contains { $0.rule == "CI-CONTROL-001" })
    }

    @Test
    func `candidate remains data while floating-action positive control fires`() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let workflows = root.appendingPathComponent(".github/workflows")
        try FileManager.default.createDirectory(
            at: workflows,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }

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
        try Data(workflow.utf8).write(to: workflows.appendingPathComponent("probe.yml"))
        try Data("#!/bin/sh\nexit 99\n".utf8).write(
            to: root.appendingPathComponent("candidate-code")
        )

        let run = Institute.CI.Control.Validation.run(
            repository: "swift-institute-test/control-candidate",
            root: root.path
        )

        #expect(run.defect == nil)
        #expect(run.findings.contains { $0.rule == "CI-117" })
        #expect(run.tsv.contains("\tCI-117\t"))
    }

    @Test
    func `canonical compositor does not retain the superseded runner label heuristic`() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let workflows = root.appendingPathComponent(".github/workflows")
        try FileManager.default.createDirectory(at: workflows, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let universal = CIValidationUniversalWorkflowTests.workflow()
            .replacingOccurrences(
                of: "  macos-release:\n    runs-on: ubuntu-latest",
                with: "  macos-release:\n    runs-on: xcode-27"
            )
            .replacingOccurrences(
                of: "  apple-simulator-build:\n    runs-on: ubuntu-latest",
                with: "  apple-simulator-build:\n    runs-on: xcode-27"
            )
        try Data(universal.utf8).write(
            to: workflows.appendingPathComponent("swift-ci.yml")
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
        try Data(host.utf8).write(
            to: workflows.appendingPathComponent("control-validate.yml")
        )

        let run = Institute.CI.Control.Validation.run(
            repository: "swift-institute/.github",
            root: root.path
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
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let run = Institute.CI.Control.Validation.run(
            repository: "swift-institute-test/control-candidate",
            root: root.path
        )

        #expect(run.findings.isEmpty)
        #expect(run.defect != nil)
        #expect(run.exitCode == 2)
    }
}
