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
                expectation: .findings(4),
                documents: ["README.md", "Docs/Diagnostics.md", "CLAUDE.md", "CHANGELOG.md", "Sources/Core/README.md"]
            ),
            .init(
                id: "markdown file admitted",
                source: "let package = Package(name: \"Fixture\")",
                path: "Package.swift",
                expectation: .clean,
                documents: [
                    "README.md", "LICENSE.md", "Sources/Core/Core.docc/Core.md",
                    "Tests/Core Tests/Fixtures/valid/MANIFEST.md", "example-app/README.md",
                    "example-app/Tests/App Tests/Fixtures/page.md",
                ],
                packages: ["example-app"]
            ),
            .init(
                id: "markdown file nested package",
                source: "let package = Package(name: \"Fixture\")",
                path: "Package.swift",
                expectation: .findings(2),
                documents: ["README.md", "example-app/README.md", "example-app/Notes.md", "example-film/README.md"],
                packages: ["example-app"]
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
            let findings = Lint.Rule.Markdown.stray(source.index.documents, packages: source.index.packages).map { document in
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

    public static let license: Swift::String = "LICENSE.md"

    public static func stray(
        _ documents: Swift::Set<Swift::String>,
        packages: Swift::Set<Swift::String> = []
    ) -> [Swift::String] {
        documents.filter { !admits($0, packages: packages) }.sorted()
    }

    public static func admits(_ document: Swift::String, packages: Swift::Set<Swift::String>) -> Swift::Bool {
        if document == license { return true }
        let package = packages.filter { document.hasPrefix($0 + "/") }.max { $0.count < $1.count }
        let relative = package.map { Swift::String(document.dropFirst($0.count + 1)) } ?? document
        if relative == readme { return true }
        let directories = relative.split(separator: "/").dropLast()
        if directories.contains(where: { $0.hasSuffix(".docc") }) { return true }
        let lowered = directories.map { $0.lowercased() }
        guard let tests = lowered.firstIndex(of: "tests") else { return false }
        return lowered[(tests + 1)...].contains("fixtures")
    }

    public static func message(_ document: Swift::String) -> Swift::String {
        "[markdown file]: `\(document)` is prose outside a package's README.md. A repository's prose is one README.md "
            + "per package, the root's and each nested package's; besides it only LICENSE.md, DocC catalogs and test "
            + "fixtures. Fold what is still true into a README.md, a type, a test or an issue, and delete the file."
    }
}
