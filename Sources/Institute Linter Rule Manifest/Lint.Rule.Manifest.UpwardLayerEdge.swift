public import Lint
public import Institute_Model
internal import SwiftSyntax

extension Lint.Rule {
    public static let `upward layer edge` = Lint.Rule.`upward layer edge`(in: nil)

    public static func `upward layer edge`(in repository: Institute.Repository.Coordinate?) -> Lint.Rule {
        Lint.Rule(
            id: "upward layer edge",
            default: .warning,
            controls: manifestUpwardLayerEdgeControls(in: repository),
            observe: { source, severity in
                guard let layer = repository?.organization.layer, layer != .control,
                    manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description)
                else {
                    return Lint.Rule.Observation(
                        findings: [],
                        coverage: .measured,
                        applicability: .inapplicable
                    )
                }
                let visitor = ManifestUpwardLayerEdgeVisitor(
                    source: source.file,
                    severity: severity,
                    converter: source.converter,
                    layer: layer.rawValue
                )
                visitor.walk(source.tree)
                return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
            }
        )
    }
}

private let manifestLayerExamples: [(layer: Institute.Organization.Layer, url: Swift::String)] = [
    (.atoms, "https://github.com/swift-atoms/swift-byte.git"),
    (.molecules, "https://github.com/swift-molecules/swift-buffer.git"),
    (.standards, "https://github.com/swift-ietf/swift-rfc-3986.git"),
    (.compositions, "https://github.com/swift-compositions/swift-json.git"),
]

private func manifestUpwardLayerEdgeControls(
    in repository: Institute.Repository.Coordinate?
) -> [Lint.Rule.Control] {
    guard let repository, repository.organization.layer != .control else {
        return [
            .init(
                id: "upward layer edge outside a layered repository",
                source: "let package = Package(name: \"swift-owner\", dependencies: ["
                    + ".package(url: \"https://github.com/swift-compositions/swift-json.git\", branch: \"main\")])",
                path: "/workspace/Package.swift",
                expectation: .clean,
                applicability: .inapplicable
            )
        ]
    }
    let layer = repository.organization.layer
    return manifestLayerExamples.map { example in
        .init(
            id: "upward layer edge \(repository.organization.rawValue) on \(example.layer)",
            source: "let package = Package(name: \"\(repository.name)\", dependencies: ["
                + ".package(url: \"\(example.url)\", branch: \"main\")])",
            path: "/workspace/\(repository.name)/Package.swift",
            expectation: example.layer > layer ? .findings(1) : .clean
        )
    }
}

private let manifestLayerNames: [Swift::Int: Swift::String] = [
    1: "atoms", 2: "molecules", 3: "standards", 4: "compositions",
]

internal func manifestLayer(ofURL url: Swift::String) -> Swift::Int? {
    Institute.Organization(url: url).map(\.layer).flatMap { $0 == .control ? nil : $0.rawValue }
}

internal final class ManifestUpwardLayerEdgeVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let layer: Swift::Int
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        layer: Swift::Int
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.layer = layer
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "package",
            let argument = node.arguments.first(where: { $0.label?.text == "url" }),
            let literal = argument.expression.as(StringLiteralExprSyntax.self),
            let url = manifestStringLiteralText(literal),
            let target = manifestLayer(ofURL: url),
            target > layer
        else {
            return .visitChildren
        }
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
                identifier: "upward layer edge",
                message: "[upward layer edge] [PACKAGE-LAYER-DIRECTION]: a \(manifestLayerNames[layer] ?? "") "
                    + "package must not depend on the \(manifestLayerNames[target] ?? "") layer (`\(url)`); "
                    + "atoms depend on atoms, molecules on atoms and molecules, standards on atoms, "
                    + "molecules and standards, compositions on every layer."
            )
        )
        return .visitChildren
    }
}
