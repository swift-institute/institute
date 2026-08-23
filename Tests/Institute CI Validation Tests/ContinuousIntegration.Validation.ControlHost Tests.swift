import ContinuousIntegration
import Testing

@testable import Institute_CI_Validation

@Suite
struct CIValidationControlHostTests {
    typealias Validator = ContinuousIntegration.Validation.ControlHost

    static let valid = """
        on:
          workflow_dispatch:
            inputs:
              repository:
                required: true
                type: string
              pull:
                required: true
                type: string
              head:
                required: true
                type: string
        permissions: {}
        jobs:
          control:
            runs-on: ubuntu-latest
            steps: []
        """

    static func findings(
        workflow: String? = valid,
        repository: String = Validator.canonicalRepository
    ) throws -> [ContinuousIntegration.Validation.Finding] {
        let subject = TemporaryRepository(repository: repository)
        if let workflow {
            subject.write(workflow, to: Validator.workflowPath)
        }
        return try Validator().findings(in: subject.subject)
    }

    @Test func `terminal host satisfies the invariant`() throws {
        #expect(try Self.findings().isEmpty)
    }

    @Test func `checker deletion is red`() throws {
        let findings = try Self.findings(workflow: nil)
        #expect(findings.count == 1)
        #expect(findings[0].rule == "CI-CONTROL-001")
        #expect(findings[0].message.contains("absent"))
    }

    @Test func `other repositories do not own the organization host`() throws {
        #expect(try Self.findings(workflow: nil, repository: "swift-institute/swift-order").isEmpty)
    }

    @Test func `self firing host is refused`() throws {
        let workflow = Self.valid.replacing(
            "on:\n  workflow_dispatch:",
            with: "on:\n  pull_request:\n  workflow_dispatch:"
        )
        #expect(
            try Self.findings(workflow: workflow).contains { $0.message.contains("dispatch-only") }
        )
    }

    @Test func `head coordinate cannot become optional`() throws {
        let workflow = Self.valid.replacing(
            "head:\n        required: true",
            with: "head:\n        required: false"
        )
        #expect(try Self.findings(workflow: workflow).contains { $0.message.contains("`head`") })
    }

    @Test func `ambient workflow permissions are refused`() throws {
        let workflow = Self.valid.replacing(
            "permissions: {}",
            with: "permissions:\n  contents: read"
        )
        #expect(
            try Self.findings(workflow: workflow).contains { $0.message.contains("permissions") }
        )
    }
}
