import GitHub_Standard
public import Institute_Model
import Institute_Repository_Policy
import Testing

enum `Institute.Repository.Policy.Prose Tests` {}

extension `Institute.Repository.Policy.Prose Tests` {
    @Suite
    struct Unit {
        @Test
        func
            `prose outside README and LICENSE is a finding, and DocC catalogs and non-markdown files are not`()
        {
            let tracked = [
                "README.md",
                "LICENSE.md",
                "Package.swift",
                "NOTES.md",
                "Sources/Core/README.md",
                "Docs/design.markdown",
                "Research/INVESTIGATION-ARC.MD",
                "CONTRIBUTING.md",
                ".github/PULL_REQUEST_TEMPLATE.md",
                "Sources/Core/Core.docc/Core.md",
                "Sources/Statute/Statute.docc/Articles/Article 1.md",
                "Sources/Core/markdown.swift",
                "README.md.txt",
                "Tests/Core Tests/Fixtures/valid/MANIFEST.md",
                ".github/scripts/tests/fixtures/skill-links/pass/alpha/SKILL.md",
                "Tests/Core Tests/NOTES.md",
                "Fixtures/notes.md",
            ]
            let repository: GitHub_Standard::GitHub.Repository.Slug = "swift-atoms/swift-affine"
            let findings = Institute.Repository.Policy.Prose.findings(in: tracked, repository: repository)
            #expect(
                findings == [
                    ".github/PULL_REQUEST_TEMPLATE.md",
                    "CONTRIBUTING.md",
                    "Docs/design.markdown",
                    "Fixtures/notes.md",
                    "NOTES.md",
                    "Research/INVESTIGATION-ARC.MD",
                    "Sources/Core/README.md",
                    "Tests/Core Tests/NOTES.md",
                ]
            )
        }

        @Test
        func
            `an organization's .github repository admits its community-health files and templates, and nothing else`()
        {
            let tracked = [
                "profile/README.md",
                "SECURITY.md",
                "CONTRIBUTING.md",
                "CODE_OF_CONDUCT.md",
                ".github/ISSUE_TEMPLATE/bug.md",
                ".github/pull_request_template.md",
                "ISSUE_TEMPLATE/feature.md",
                "brand/README.md",
                "profile/NOTES.md",
            ]
            let repository: GitHub_Standard::GitHub.Repository.Slug = "swift-molecules/.github"
            let findings = Institute.Repository.Policy.Prose.findings(in: tracked, repository: repository)
            #expect(findings == ["brand/README.md", "profile/NOTES.md"])
        }

        @Test
        func `swift-institute Issues is exempt: its reproducer folders are the issue record`() {
            let tracked = ["README.md", "swift-issue-borrowing-actor-closure/README.md", "Tooling/NOTES.md"]
            let findings = Institute.Repository.Policy.Prose.findings(in: tracked, repository: "swift-institute/Issues")
            #expect(findings.isEmpty)
        }

        @Test
        func `a fork kept for upstream pull requests is exempt, and a fork used as a package is not`() {
            let tracked = ["README.md", "Documentation/Usage.md", "CHANGELOG.md"]
            let prose = Institute.Repository.Policy.Prose.self
            let pullRequests = prose.findings(in: tracked, repository: "coenttb/swift-package-manager")
            let package = prose.findings(in: tracked, repository: "swift-compositions/swift-sqlite")
            #expect(pullRequests.isEmpty)
            #expect(package == ["CHANGELOG.md", "Documentation/Usage.md"])
        }
    }
}
