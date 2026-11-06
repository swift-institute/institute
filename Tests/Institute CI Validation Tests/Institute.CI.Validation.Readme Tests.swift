import GitHub_Standard
import Institute_CI_Model
import Institute_CI_Validation
public import Institute_Model
import Testing

@testable import Institute_CI_Validation

/// The family-routing behaviour of `Institute.CI.Validation.Readme` that the
/// fixture corpus (readme-017/026/160) does not carry: exemption,
/// the unset family, the Family G profile paths, and Family F's implicit
/// README. The per-rule predicates themselves are exercised by the
/// shared harness over the corpus, and proved against the retired
/// implementation by the differential gate — these tests do not repeat
/// that.
@Suite
struct CIValidationReadmeTests {
    let validator = Institute.CI.Validation.Readme()

    @Suite
    struct Routing {
        let validator = Institute.CI.Validation.Readme()

        @Test func `a declared exemption emits nothing`() throws {
            let repository = TemporaryRepository()
            repository.write("readme:\n  exempt: vendored-upstream\n", to: ".github/metadata.yaml")
            repository.write("no H1 at all\n", to: "README.md")
            #expect(try validator.findings(in: repository.subject).isEmpty)
        }

        @Test func `an unset family is a finding not a pass`() throws {
            let repository = TemporaryRepository()
            repository.write("# Title\n", to: "README.md")
            let findings = try validator.findings(in: repository.subject)
            #expect(findings.map(\.rule) == ["README-family-unset"])
        }

        @Test func `an unrecognised exemption falls through to unset`() throws {
            let repository = TemporaryRepository()
            repository.write("readme:\n  exempt: did-not-get-to-it\n", to: ".github/metadata.yaml")
            let findings = try validator.findings(in: repository.subject)
            #expect(findings.map(\.rule) == ["README-family-unset"])
        }

        @Test func `a missing family E readme is a presence finding`() throws {
            let repository = TemporaryRepository()
            repository.write("readme:\n  family: E\n", to: ".github/metadata.yaml")
            let findings = try validator.findings(in: repository.subject)
            #expect(findings.map(\.rule) == ["README-presence"])
            #expect(findings.first?.message.contains("family=E") == true)
        }

        @Test func `a missing family F readme is a namespace reservation`() throws {
            let repository = TemporaryRepository()
            repository.write("readme:\n  family: F\n", to: ".github/metadata.yaml")
            #expect(try validator.findings(in: repository.subject).isEmpty)
        }
    }

    @Suite
    struct `Family G Paths` {
        let validator = Institute.CI.Validation.Readme()

        @Test func `the org dot-github repo reads its profile at repo root`() throws {
            let repository = TemporaryRepository(repository: "swift-institute/.github")
            repository.write("readme:\n  family: G\n", to: ".github/metadata.yaml")
            repository.write("# Org\n\nProfile.\n", to: "profile/README.md")
            #expect(try validator.findings(in: repository.subject).isEmpty)
        }

        @Test func `any other repo reads the nested org-relative path`() throws {
            let repository = TemporaryRepository(repository: "swift-institute/other")
            repository.write("readme:\n  family: G\n", to: ".github/metadata.yaml")
            repository.write(
                "# Org\n\n## Installation\n\nforbidden\n",
                to: ".github/profile/README.md"
            )
            let findings = try validator.findings(in: repository.subject)
            #expect(findings.map(\.rule) == ["README-117"])
        }
    }

    @Suite
    struct `Family G Shape` {
        let validator = Institute.CI.Validation.Readme()

        func findings(_ profile: String, repository: GitHub_Standard::GitHub.Repository.Slug = "swift-atoms/.github") throws -> [Institute.CI.Validation.Finding] {
            let temporary = TemporaryRepository(repository: repository)
            temporary.write("readme:\n  family: G\n", to: ".github/metadata.yaml")
            temporary.write(profile, to: "profile/README.md")
            return try validator.findings(in: temporary.subject)
        }

        @Test func `a start here section is the one allowed`() throws {
            #expect(try findings("# Org\n\nUse this.\n\n## Start here\n\n- a\n").isEmpty)
        }

        @Test func `any other section is a finding`() throws {
            #expect(try findings("# Org\n\n## License\n\nApache.\n").map(\.rule) == ["README-117"])
        }

        @Test func `a code block is a finding`() throws {
            #expect(try findings("# Org\n\n```swift\nlet a = 1\n```\n").map(\.rule) == ["README-117"])
        }

        @Test func `the control organization's profile is not bound`() throws {
            #expect(try findings("# Org\n\n## CI\n\nText.\n", repository: "swift-institute/.github").isEmpty)
        }
    }

    @Suite
    struct `Family E Shape` {
        let validator = Institute.CI.Validation.Readme()

        func rules(_ readme: String) throws -> [Institute.CI.Validation.Rule] {
            let temporary = TemporaryRepository(repository: "swift-atoms/swift-example")
            temporary.write("readme:\n  family: E\n", to: ".github/metadata.yaml")
            temporary.write(readme, to: "README.md")
            return try validator.findings(in: temporary.subject).map(\.rule)
        }

        @Test func `the finished shape has no findings`() throws {
            #expect(try rules("# swift-example\n\nUse this.\nSecond line.\n\n## Laws\n\n- A law.\n").isEmpty)
        }

        @Test func `no laws section is fine`() throws {
            #expect(try rules("# swift-example\n\nUse this.\n").isEmpty)
        }

        @Test func `a title that isn't the repository's name is a finding`() throws {
            #expect(try rules("# Example\n\nUse this.\n") == ["README-161"])
        }

        @Test func `two paragraphs are a finding`() throws {
            #expect(try rules("# swift-example\n\nUse this.\n\nAnd this.\n\n## Laws\n\n- A law.\n") == ["README-162"])
        }

        @Test func `no paragraph is a finding`() throws {
            #expect(try rules("# swift-example\n\n## Laws\n\n- A law.\n") == ["README-162"])
        }

        @Test func `text after the laws heading doesn't count`() throws {
            #expect(try rules("# swift-example\n\nUse this.\n\n## Laws\n\nIntro.\n\nMore.\n").isEmpty)
        }
    }

    @Suite
    struct Registry {
        @Test func `every corpus directory resolves to a registered rule`() {
            for directory in ["readme-017", "readme-026", "readme-160"] {
                #expect(
                    Institute.CI.Validation.Registry.rule(
                        forCorpusDirectory: directory
                    ) != nil
                )
            }
        }
    }
}
