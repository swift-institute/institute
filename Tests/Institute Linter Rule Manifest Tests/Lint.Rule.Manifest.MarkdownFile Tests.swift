import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension `Lint.Rule Tests` {
    @Suite
    struct `markdown file Tests` {
        @Suite struct Unit {}
    }
}

extension `Lint.Rule Tests`.`markdown file Tests`.Unit {
    @Test
    func `controls hold`() {
        for outcome in Lint.Rule.`markdown file`.outcomes() {
            #expect(outcome.holds, "\(outcome)")
        }
    }

    @Test
    func `every markdown file but the root readme is stray, in path order`() {
        let documents: Swift::Set<Swift::String> = ["README.md", "Docs/Diagnostics.md", "Docs/Agent Sessions.md"]
        #expect(Lint.Rule.Markdown.stray(documents) == ["Docs/Agent Sessions.md", "Docs/Diagnostics.md"])
    }

    @Test
    func `each nested package has one readme, and a folder without a manifest has none`() {
        let documents: Swift::Set<Swift::String> = [
            "README.md", "example-app/README.md", "example-server/README.md", "example-film/README.md",
            "example-server/CHANGELOG.md", "example-app/Sources/App/README.md",
        ]
        let stray = Lint.Rule.Markdown.stray(documents, packages: ["example-app", "example-server"])
        #expect(stray == ["example-app/Sources/App/README.md", "example-film/README.md", "example-server/CHANGELOG.md"])
    }

    @Test
    func `agent instructions and change logs are stray at the root`() {
        let documents: Swift::Set<Swift::String> = ["README.md", "LICENSE.md", "CLAUDE.md", "AGENTS.md", "CHANGELOG.md"]
        #expect(Lint.Rule.Markdown.stray(documents) == ["AGENTS.md", "CHANGELOG.md", "CLAUDE.md"])
    }
}
