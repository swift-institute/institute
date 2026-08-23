import GitHub_Continuous_Integration
import ContinuousIntegration
import Testing

@testable import Institute_CI_Validation

@Suite
struct CIValidationUniversalWorkflowTests {
    typealias Validator = ContinuousIntegration.Validation.UniversalWorkflow

    static func workflow(
        windowsAdvisory: Bool = false,
        windowsPresent: Bool = true,
        aggregateNeeds: [String] = [
            "plan", "linux-release", "macos-release", "windows-release",
            "format", "lint", "swift-linter",
        ],
        skippedGating: String? = nil,
        advisoryNeeds: [String] = [
            "plan", "linux-6-4", "linux-nightly", "apple-simulator-build",
            "embedded", "embedded-wasm-sdk", "android-build",
            "static-linux-musl-build",
        ]
    ) -> String {
        let catalogue = Validator.catalogue.filter { $0 != "windows-release" || windowsPresent }
        return "jobs:\n"
            + catalogue.map { name in
                var lines = ["  \(name):"]
                if name == "ci-ok" {
                    lines.append("    needs: [\(aggregateNeeds.joined(separator: ", "))]")
                } else if name == "advisory-summary" {
                    lines.append("    needs: [\(advisoryNeeds.joined(separator: ", "))]")
                    lines.append("    continue-on-error: true")
                } else if name == "windows-release" {
                    lines.append("    runs-on: windows-latest")
                    if windowsAdvisory { lines.append("    continue-on-error: true") }
                } else {
                    lines.append("    runs-on: ubuntu-latest")
                }
                if Validator.gating.contains(name) {
                    let condition =
                        skippedGating == name
                        ? "false"
                        : "${{ contains(format(',{0},', needs.plan.outputs.legs), ',\(name),') }}"
                    lines.append("    if: \(condition)")
                }
                return lines.joined(separator: "\n")
            }.joined(separator: "\n") + "\n"
    }

    static func findings(
        _ workflow: String
    ) throws -> [ContinuousIntegration.Validation.Finding] {
        let repository = TemporaryRepository(repository: "swift-institute-test/universal")
        repository.write(workflow, to: ".github/workflows/swift-ci.yml")
        return try Validator().findings(in: repository.subject)
    }

    @Test func `planner driven workflow satisfies the terminal contract`() throws {
        #expect(try Self.findings(Self.workflow()).isEmpty)
    }

    @Test func `Windows advisory is refused`() throws {
        let findings = try Self.findings(Self.workflow(windowsAdvisory: true))
        #expect(findings.contains { $0.rule == "CI-099" })
    }

    @Test func `absent Windows gating job is refused`() throws {
        let findings = try Self.findings(Self.workflow(windowsPresent: false))
        #expect(findings.contains { $0.message.contains("windows-release") })
    }

    @Test func `incomplete aggregate is refused`() throws {
        let findings = try Self.findings(
            Self.workflow(aggregateNeeds: [
                "plan", "linux-release", "macos-release", "format", "lint", "swift-linter",
            ])
        )
        #expect(
            findings.contains {
                $0.message.contains("does not consume gating result `windows-release`")
            }
        )
    }

    @Test func `selected gating job cannot be statically skipped`() throws {
        let findings = try Self.findings(Self.workflow(skippedGating: "format"))
        #expect(findings.contains { $0.message.contains("`format` is not selected") })
    }

    @Test func `Windows cannot move into the advisory result set`() throws {
        let findings = try Self.findings(
            Self.workflow(advisoryNeeds: ["plan", "windows-release"])
        )
        #expect(findings.contains { $0.rule == "CI-099" && $0.message.contains("windows-release") })
    }
}
