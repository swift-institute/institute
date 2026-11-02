public import Lint

extension Lint.Rule {
    public static let `markdown file` = Lint.Rule(
        id: "markdown file",
        default: .warning,
        controls: [
            .init(
                id: "markdown file readme only",
                source: "let package = Package(name: \"Fixture\")",
                path: "Package.swift",
                expectation: .clean,
                documents: ["README.md"]
            ),
            .init(
                id: "markdown file others",
                source: "let package = Package(name: \"Fixture\")",
                path: "Package.swift",
                expectation: .findings(3),
                documents: ["README.md", "Docs/Diagnostics.md", "LICENSE.md", "Sources/Core/README.md"]
            ),
            .init(
                id: "markdown file documentation catalog",
                source: "let package = Package(name: \"Fixture\")",
                path: "Package.swift",
                expectation: .findings(1),
                documents: ["Sources/Core/Core.docc/Core.md"]
            ),
            .init(
                id: "markdown file source",
                source: "struct Value {}",
                path: "Sources/Core/Value.swift",
                expectation: .clean,
                applicability: .inapplicable,
                documents: ["Docs/Diagnostics.md"]
            ),
            .init(
                id: "markdown file nested manifest",
                source: "let package = Package(name: \"Runner\")",
                path: "Runner/Package.swift",
                expectation: .clean,
                applicability: .inapplicable,
                documents: ["Runner/Notes.md"]
            ),
        ],
        observe: { source, severity in
            guard manifestIsRootPackageManifest(source.path.underlying) else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let findings = Lint.Rule.Markdown.stray(source.index.documents).map { document in
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.file.fileID,
                        filePath: source.file.filePath,
                        line: 1,
                        column: 1
                    ),
                    severity: severity,
                    identifier: "markdown file",
                    message: Lint.Rule.Markdown.message(document)
                )
            }
            return Lint.Rule.Observation(findings: findings, coverage: .measured)
        }
    )
}

extension Lint.Rule {
    public enum Markdown {}
}

extension Lint.Rule.Markdown {
    public static let readme: Swift::String = "README.md"

    public static func stray(_ documents: Swift::Set<Swift::String>) -> [Swift::String] {
        documents.filter { $0 != Self.readme }.sorted()
    }

    public static func message(_ document: Swift::String) -> Swift::String {
        "[markdown file]: `\(document)` is markdown other than the root README.md, the only markdown a repository "
            + "carries. Fold what is still true into README.md, a type, a test or an issue, and delete the file."
    }
}
