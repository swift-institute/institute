public import Institute_Model
import Institute_Repository_Policy
import Testing

extension Institute.Repository.Policy.Prose {
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
            ]
            #expect(
                Institute.Repository.Policy.Prose.findings(
                    in: tracked, repository: "swift-atoms/swift-affine") == [
                        ".github/PULL_REQUEST_TEMPLATE.md",
                        "CONTRIBUTING.md",
                        "Docs/design.markdown",
                        "NOTES.md",
                        "Research/INVESTIGATION-ARC.MD",
                        "Sources/Core/README.md",
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
            #expect(
                Institute.Repository.Policy.Prose.findings(
                    in: tracked, repository: "swift-molecules/.github") == [
                        "brand/README.md",
                        "profile/NOTES.md",
                    ]
            )
        }
    }
}
