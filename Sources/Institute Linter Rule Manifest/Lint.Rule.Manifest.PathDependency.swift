public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `path dependency` = Lint.Rule(
        id: "path dependency",
        default: .warning,
        controls: [
            .init(
                id: "path dependency local package",
                source: "let package = Package(name: \"Fixture\", "
                    + "dependencies: [.package(path: \"../swift-owner\")])",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "path dependency named local package",
                source: "let dependency = Package.Dependency.package(name: \"swift-owner\", path: \"../swift-owner\")",
                path: "Package@swift-6.4.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "path dependency nested test manifest parent",
                source: "let package = Package(name: \"testing\", "
                    + "dependencies: [.package(path: \"..\")])",
                path: "Tests/Package.swift",
                expectation: .clean
            ),
            .init(
                id: "path dependency nested test manifest sibling",
                source: "let package = Package(name: \"testing\", "
                    + "dependencies: [.package(path: \"..\"), .package(path: \"../../swift-owner\")])",
                path: "Tests/Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "path dependency url",
                source: "let package = Package(name: \"Fixture\", dependencies: ["
                    + ".package(url: \"https://github.com/swift-atoms/swift-owner.git\", branch: \"main\")])",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "path dependency target path",
                source: "let target = Target.target(name: \"Fixture\", path: \"Sources/Fixture\")",
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "path dependency outside manifest",
                source: "let dependency = Package.Dependency.package(path: \"../swift-owner\")",
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
            let visitor = ManifestPathDependencyVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                nestedTestManifest: manifestIsNestedTestManifest(source.file.filePath)
            )
            visitor.walk(source.tree)
            return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
        }
    )
}

@usableFromInline
internal let manifestPathDependencyMessage: Swift::String =
    "[path dependency] [PACKAGE-PATH-DEPENDENCY]: a package dependency must be "
    + "declared by URL, never by `path:`; local checkouts are provided by the "
    + "workspace, not by the manifest. The one exception is the nested test "
    + "manifest, `Tests/Package.swift`, reaching its parent as `.package(path: \"..\")`."

internal func manifestIsNestedTestManifest(_ filePath: Swift::String) -> Swift::Bool {
    let components = filePath.split(separator: "/", omittingEmptySubsequences: true)
    return components.last == "Package.swift"
        && components.dropLast().last == "Tests"
}

internal final class ManifestPathDependencyVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let nestedTestManifest: Swift::Bool
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        nestedTestManifest: Swift::Bool
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.nestedTestManifest = nestedTestManifest
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "package",
            let path = node.arguments.first(where: { $0.label?.text == "path" }),
            !(nestedTestManifest && isParent(path.expression))
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
                    identifier: "path dependency",
                    message: manifestPathDependencyMessage
                )
            )
        }
        return .visitChildren
    }

    private func isParent(_ expression: ExprSyntax) -> Swift::Bool {
        guard let literal = expression.as(StringLiteralExprSyntax.self) else { return false }
        return manifestStringLiteralText(literal) == ".."
    }
}
