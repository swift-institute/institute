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
}
