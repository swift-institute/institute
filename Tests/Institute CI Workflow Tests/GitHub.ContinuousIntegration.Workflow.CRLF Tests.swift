import Institute_CI_GitHub
import GitHub_Standard
import Testing

@testable import Institute_CI_Workflow

/// Regression coverage for the Windows-only `.noJobs` defect
/// (institute-continuous-integration#13): a CRLF-encoded workflow
/// document parsed to a single top-level key and zero jobs.
///
/// Root cause: `Line.scan` split on `"\n"` as a `Character`. Swift's
/// `Character` is an extended grapheme cluster, and CR+LF is itself one
/// grapheme cluster, so `text.split(separator: "\n")` on a CRLF document
/// matches nothing and the whole document collapses into one pseudo-line.
/// This is not Windows-conditional code — it is a Unicode-model fact that
/// fires on any platform whenever the *input bytes* are CRLF, which in
/// practice means every Windows `git checkout` of an LF-committed
/// workflow file (default `core.autocrlf`). Reproduced here on macOS by
/// feeding the parser CRLF text directly, with no Windows machine
/// required.
@Suite
struct CIWorkflowCRLFTests {
    static let caller = """
        name: CI

        on:
          push:
            branches: [main]
          pull_request:

        jobs:
          ci:
            uses: swift-primitives/.github/.github/workflows/swift-ci.yml@main
            secrets: inherit
          lint:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v6
        """

    @Test func `CRLF document parses the same jobs as its LF original`() throws {
        let lf = Self.caller
        let crlf = lf.replacingOccurrences(of: "\n", with: "\r\n")

        let lfDocument = try GitHub.ContinuousIntegration.Workflow.Document(
            name: "ci.yml", text: lf)
        let crlfDocument = try GitHub.ContinuousIntegration.Workflow.Document(
            name: "ci.yml", text: crlf)

        #expect(crlfDocument.jobs.map(\.name) == lfDocument.jobs.map(\.name))
        #expect(crlfDocument.jobs.map(\.name) == ["ci", "lint"])
    }

    @Test func `a lone CR line ending is also normalised`() throws {
        let lf = Self.caller
        let cr = lf.replacingOccurrences(of: "\n", with: "\r")

        let document = try GitHub.ContinuousIntegration.Workflow.Document(
            name: "ci.yml", text: cr)
        #expect(document.jobs.map(\.name) == ["ci", "lint"])
    }
}
