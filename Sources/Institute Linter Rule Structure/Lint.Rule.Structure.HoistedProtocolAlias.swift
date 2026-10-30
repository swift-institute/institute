public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `hoisted protocol alias` = Lint.Rule(
        id: "hoisted protocol alias",
        default: .warning,
        controls: [
            .init(
                id: "hoisted protocol alias self conformance",
                source: "extension Parser.Error.Located: Parser.Error.Located.Protocol {}",
                path: "Sources/Structure Core/Located.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "hoisted protocol alias hoisted name",
                source: "extension Parser.Error.Located: _LocatedErrorProtocol {}",
                path: "Sources/Structure Core/Located.swift",
                expectation: .clean
            ),
            .init(
                id: "hoisted protocol alias consumer conformance",
                source: "extension MyError: Parser.Error.Located.Protocol {}",
                path: "Sources/Structure Core/MyError.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = StructureHoistedProtocolAliasVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let structureHoistedProtocolAliasMessage: Swift::String =
    "[hoisted protocol alias] [API-IMPL-009]: declare the protocol hoisted as "
    + "`_XProtocol` and expose it as `X.Protocol`; the declaring module conforms "
    + "through `_XProtocol`, never through the `X.Protocol` path."

internal func structureHoistedProtocolAliasIsSelfProtocolConformance(
    extendedName: Swift::String,
    inheritedName: Swift::String
) -> Swift::Bool {
    return inheritedName == "\(extendedName).Protocol"
}

internal final class StructureHoistedProtocolAliasVisitor: SyntaxVisitor {
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

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard
            let extendedName = structureDottedName(
                of: node.extendedType
            )
        else {
            return .visitChildren
        }
        guard let inheritance = node.inheritanceClause else {
            return .visitChildren
        }
        for inherited in inheritance.inheritedTypes {
            guard
                let inheritedName = structureDottedName(
                    of: inherited.type
                )
            else { continue }
            guard
                structureHoistedProtocolAliasIsSelfProtocolConformance(
                    extendedName: extendedName,
                    inheritedName: inheritedName
                )
            else { continue }
            let location = converter.location(
                for: inherited.type.positionAfterSkippingLeadingTrivia
            )
            matches.append(
                Diagnostic.Record(
                    location: Source.Location(
                        fileID: source.fileID,
                        filePath: source.filePath,
                        line: location.line,
                        column: location.column
                    ),
                    severity: severity,
                    identifier: "hoisted protocol alias",
                    message: structureHoistedProtocolAliasMessage
                )
            )
        }
        return .visitChildren
    }
}
