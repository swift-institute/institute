import Lint
import Linter_Rules_Test_Support
import SwiftParser
import Testing

@testable import Institute_Linter_Rule_Manifest

extension Lint.Rule {
    @Suite
    struct `trait consistency Tests` {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Lint.Rule.`trait consistency Tests` {
    static let manifest = """
        let package = Package(
            name: "swift-owner",
            traits: [
                .trait(name: "Coder", enabledTraits: ["Parser"]),
                .trait(name: "Parser"),
                .trait(name: "Serializer"),
            ],
            dependencies: [
                .package(url: "https://github.com/swift-atoms/swift-parser.git", branch: "main",
                         traits: [.trait(name: "Map", condition: .when(traits: ["Parser"]))]),
            ],
            targets: [
                .target(
                    name: "Owner",
                    dependencies: [
                        .product(name: "Parser", package: "swift-parser"),
                        .product(name: "Checkpoint", package: "swift-checkpoint"),
                        .product(name: "Serializer", package: "swift-serializer", condition: .when(traits: ["Parser"])),
                    ]
                ),
            ]
        )
        """

    static func index(_ files: [Swift::String: Swift::String]) -> Lint.Source.Index {
        var index = Lint.Source.Index.collect(from: Parser.parse(source: manifest), path: "Package.swift")
        for (path, source) in files { index.merge(.collect(from: Parser.parse(source: source), path: path)) }
        return index
    }

    static func parsed(_ files: [Swift::String: Swift::String], manifest: Swift::String = manifest) -> Lint.Source.Parsed {
        Lint.Source.parsed(from: manifest, file: "Package.swift", index: index(files))
    }
}

extension Lint.Rule.`trait consistency Tests`.Unit {
    @Test
    func `guarded imports want the union of their guards, and the repair adds it`() throws {
        let files = [
            "Sources/Owner/A.swift": "#if Coder\nimport Checkpoint\n#endif",
            "Sources/Owner/B.swift": "#if Parser && os(Linux)\nimport Checkpoint\n#endif",
        ]
        let observation = Lint.Rule.`trait consistency`.observe(Lint.Rule.`trait consistency Tests`.parsed(files), .warning)
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("condition: .when(traits: [\"Coder\", \"Parser\"])"))
        guard case .edits(let edits) = Lint.Rule.`trait consistency`.repair(Lint.Rule.`trait consistency Tests`.parsed(files)),
            case .rewrite(_, let contents) = edits.first
        else {
            Issue.record("expected a rewrite")
            return
        }
        let expected =
            ".product(name: \"Checkpoint\", package: \"swift-checkpoint\", condition: .when(traits: [\"Coder\", \"Parser\"]))"
        #expect(contents.contains(expected))
        let repaired = Lint.Rule.`trait consistency`.observe(
            Lint.Rule.`trait consistency Tests`.parsed(files, manifest: contents),
            .warning
        )
        #expect(repaired.findings.isEmpty)
    }

    @Test
    func `a conditioned dependency imported outside its guard is flagged and not repaired`() {
        let files = ["Sources/Owner/A.swift": "#if Serializer\nimport Serializer\n#endif"]
        let parsed = Lint.Rule.`trait consistency Tests`.parsed(files)
        let observation = Lint.Rule.`trait consistency`.observe(parsed, .warning)
        #expect(observation.findings.count == 1)
        #expect(observation.findings[0].message.contains("Sources/Owner/A.swift:2"))
        #expect(Lint.Rule.`trait consistency`.repair(Lint.Rule.`trait consistency Tests`.parsed(files)) == .refused(.repairUnavailable))
    }
}

extension Lint.Rule.`trait consistency Tests`.`Edge Case` {
    @Test
    func `a guard implying the condition through enabled traits is enough`() {
        let files = ["Sources/Owner/A.swift": "#if Coder\nimport Serializer\n#endif"]
        let observation = Lint.Rule.`trait consistency`.observe(Lint.Rule.`trait consistency Tests`.parsed(files), .warning)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `an import in another target is not this target's`() {
        let files = ["Sources/Other/A.swift": "#if Parser\nimport Parser\n#endif"]
        let observation = Lint.Rule.`trait consistency`.observe(Lint.Rule.`trait consistency Tests`.parsed(files), .warning)
        #expect(observation.findings.isEmpty)
    }

    @Test
    func `an unused dependency is left to the unused-dependency warning`() {
        let observation = Lint.Rule.`trait consistency`.observe(Lint.Rule.`trait consistency Tests`.parsed([:]), .warning)
        #expect(observation.findings.isEmpty)
    }
}
