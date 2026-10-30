public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `default trait` = Lint.Rule(
        id: "default trait",
        default: .warning,
        controls: [
            .init(
                id: "default trait declared",
                source: "let package = Package(name: \"Fixture\", traits: ["
                    + ".trait(name: \"Parser\"), .default(enabledTraits: [\"Parser\"])])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "default trait none",
                source: "let package = Package(name: \"Fixture\", traits: [.trait(name: \"Parser\")])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "default trait dependency request",
                source: "let package = Package(name: \"Fixture\", dependencies: ["
                    + ".package(url: \"https://github.com/swift-atoms/swift-manifest.git\", "
                    + "branch: \"main\", traits: [.defaults, \"Parser\"])])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "default trait outside manifest",
                source: "let trait = Trait.default(enabledTraits: [\"Parser\"])",
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
            let visitor = ManifestDefaultTraitVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
        }
    )
}

@usableFromInline
internal let manifestDefaultTraitMessage: Swift::String =
    "[default trait] [PACKAGE-DEFAULT-TRAIT]: a package must not declare default "
    + "traits; every consumer requests the traits it uses explicitly."

internal final class ManifestDefaultTraitVisitor: SyntaxVisitor {
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
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "default",
            node.arguments.contains(where: { $0.label?.text == "enabledTraits" })
        {
            let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "default trait",
                    message: manifestDefaultTraitMessage
                )
            )
        }
        return .visitChildren
    }
}
