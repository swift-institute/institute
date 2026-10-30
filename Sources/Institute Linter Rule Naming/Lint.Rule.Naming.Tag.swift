public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `tag suffix` = Lint.Rule(
        id: "tag suffix",
        default: .warning,
        controls: [
            .init(
                id: "tag suffix phantom type",
                source: "struct CardinalTag {}",
                path: "Sources/Naming Core/PhantomTag.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "tag suffix concept name",
                source: "struct Cardinal {}",
                path: "Sources/Naming Core/ConceptName.swift",
                expectation: .clean
            ),
            .init(
                id: "tag suffix data type",
                source: "struct XMLTag { let name: String }",
                path: "Sources/Naming Core/DataType.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingTagVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingTagMessage: Swift::String =
    "[tag suffix] [API-NAME-010]: phantom-type tags MUST use the concept name "
    + "directly (`enum Cardinal {}`, `struct Millimeter {}`), never a `Tag` suffix."

internal final class NamingTagVisitor: SyntaxVisitor {
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

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        guard name.hasSuffix("Tag"), name != "Tag" else { return .visitChildren }
        guard !namingHasStoredInstanceProperty(node.memberBlock) else { return .visitChildren }
        emit(at: node.name.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        guard name.hasSuffix("Tag"), name != "Tag" else { return .visitChildren }
        guard !namingHasEnumCase(node.memberBlock) else { return .visitChildren }
        emit(at: node.name.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "tag suffix",
                message: namingTagMessage
            )
        )
    }
}
