import Lint
import Linter_Rules_Test_Support
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `redirected dependency url Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Lint.Rule.`redirected dependency url Tests` {
    static func findings(_ manifest: Swift::String) -> [Diagnostic.Record] {
        Lint.Rule.`redirected dependency url`
            .observe(Lint.Source.parsed(from: manifest, file: "Package.swift"), .warning)
            .findings
    }

    static func manifest(_ url: Swift::String) -> Swift::String {
        "let package = Package(name: \"Fixture\", dependencies: [.package(url: \"\(url)\", branch: \"main\")])"
    }
}

extension Lint.Rule.`redirected dependency url Tests`.Unit {
    @Test
    func `a moved repository names its current url`() {
        let findings = Lint.Rule.`redirected dependency url Tests`.findings(
            Lint.Rule.`redirected dependency url Tests`.manifest("https://github.com/swift-standards/swift-http-standard.git")
        )
        #expect(findings.count == 1)
        #expect(findings.first?.message.contains("swift-standards/swift-http") == true)
    }

    @Test
    func `every url of a renamed organisation is flagged`() {
        let findings = Lint.Rule.`redirected dependency url Tests`.findings(
            Lint.Rule.`redirected dependency url Tests`.manifest("https://github.com/swift-foundations/swift-linter")
        )
        #expect(findings.count == 1)
    }
}

extension Lint.Rule.`redirected dependency url Tests`.`Edge Case` {
    @Test
    func `non-GitHub and canonical urls are clean`() {
        #expect(
            Lint.Rule.`redirected dependency url Tests`.findings(
                Lint.Rule.`redirected dependency url Tests`.manifest("https://github.com/swift-atoms/swift-tagged.git")
            ).isEmpty
        )
        #expect(
            Lint.Rule.`redirected dependency url Tests`.findings(
                Lint.Rule.`redirected dependency url Tests`.manifest("https://gitlab.com/swift-molecules/swift-async.git")
            ).isEmpty
        )
    }

    @Test
    func `a trailing slash and ssh form are recognised`() {
        #expect(
            Lint.Rule.`redirected dependency url Tests`.findings(
                Lint.Rule.`redirected dependency url Tests`.manifest("https://github.com/swift-molecules/swift-geometry/")
            ).count == 1
        )
        #expect(
            Lint.Rule.`redirected dependency url Tests`.findings(
                Lint.Rule.`redirected dependency url Tests`.manifest("git@github.com:swift-molecules/swift-geometry.git")
            ).count == 1
        )
    }
}
