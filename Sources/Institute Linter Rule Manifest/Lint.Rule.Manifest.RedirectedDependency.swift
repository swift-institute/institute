public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `redirected dependency url` = Lint.Rule(
        id: "redirected dependency url",
        default: .warning,
        controls: [
            .init(
                id: "redirected dependency url moved repository",
                source: "let package = Package(name: \"Fixture\", dependencies: ["
                    + ".package(url: \"https://github.com/swift-molecules/swift-async.git\", branch: \"main\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "redirected dependency url renamed organisation",
                source: "let package = Package(name: \"Fixture\", dependencies: ["
                    + ".package(url: \"https://github.com/swift-primitives/swift-tagged-primitives\", branch: \"main\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "redirected dependency url canonical",
                source: "let package = Package(name: \"Fixture\", dependencies: ["
                    + ".package(url: \"https://github.com/swift-atoms/swift-async.git\", branch: \"main\")])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "redirected dependency url case-insensitive",
                source: "let package = Package(name: \"Fixture\", dependencies: ["
                    + ".package(url: \"https://github.com/Swift-Molecules/Swift-Tagged.git\", branch: \"main\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "redirected dependency url outside manifest",
                source: "let url = \"https://github.com/swift-molecules/swift-async.git\"",
                path: "Sources/Fixture/Fixture.swift",
                expectation: .clean,
                applicability: .inapplicable
            ),
        ],
        observe: { source, severity in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description) else {
                return Lint.Rule.Observation(
                    findings: [],
                    coverage: .measured,
                    applicability: .inapplicable
                )
            }
            let visitor = ManifestRedirectedDependencyVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
        }
    )
}

internal let manifestRedirectedRepositories: [Swift::String: Swift::String] = [
    "swift-compositions/swift-records": "swift-compositions/swift-postgresql",
    "swift-compositions/swift-structured-queries-postgres": "swift-compositions/swift-sql",
    "swift-molecules/swift-async": "swift-atoms/swift-async",
    "swift-molecules/swift-geometry": "swift-atoms/swift-geometry",
    "swift-molecules/swift-tagged": "swift-atoms/swift-tagged",
    "swift-standards/swift-http-standard": "swift-standards/swift-http",
]

internal let manifestRenamedOrganisations: Swift::Set<Swift::String> = [
    "swift-foundations",
    "swift-primitives",
]

internal func manifestRedirectedDependencyMessage(
    _ repository: Swift::String,
    canonical: Swift::String?
) -> Swift::String {
    "[redirected dependency url]: `\(repository)` is a GitHub redirect "
        + (canonical.map { "to `\($0)`; depend on `https://github.com/\($0).git`. " }
            ?? "(its organisation was renamed); depend on the repository's current URL. ")
        + "Two spellings of one package in a graph make SwiftPM plan it twice."
}

internal func manifestGitHubRepository(_ url: Swift::String) -> Swift::String? {
    let lowered = url.lowercased()
    let prefixes = ["https://github.com/", "http://github.com/", "git@github.com:"]
    guard let prefix = prefixes.first(where: lowered.hasPrefix) else { return nil }
    var path = Swift::String(lowered.dropFirst(prefix.count))
    if path.hasSuffix("/") { path.removeLast() }
    if path.hasSuffix(".git") { path.removeLast(4) }
    return path.split(separator: "/").count == 2 ? path : nil
}

internal final class ManifestRedirectedDependencyVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "package",
            let argument = node.arguments.first(where: { $0.label?.text == "url" }),
            let literal = argument.expression.as(StringLiteralExprSyntax.self),
            literal.segments.count == 1,
            let segment = literal.segments.first?.as(StringSegmentSyntax.self),
            let repository = manifestGitHubRepository(segment.content.text)
        else { return .visitChildren }
        let canonical = manifestRedirectedRepositories[repository]
        let organisation = repository.split(separator: "/").first.map(Swift::String.init) ?? ""
        guard canonical != nil || manifestRenamedOrganisations.contains(organisation) else {
            return .visitChildren
        }
        let location = converter.location(for: literal.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "redirected dependency url",
                message: manifestRedirectedDependencyMessage(repository, canonical: canonical)
            )
        )
        return .visitChildren
    }
}
