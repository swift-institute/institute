public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `single type namespace` = Lint.Rule(
        id: "single type namespace",
        default: .warning,
        controls: [
            .init(
                id: "single type namespace one type",
                source: "public enum Cooperative { public struct Executor {} }",
                path: "Sources/Naming Core/SingleNestedType.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "single type namespace two types",
                source: "public enum Cooperative { public struct Executor {}; public struct Scheduler {} }",
                path: "Sources/Naming Core/TwoNestedTypes.swift",
                expectation: .clean
            ),
            .init(
                id: "single type namespace inhabited enum",
                source: "public enum State { case ready; public struct Metadata {} }",
                path: "Sources/Naming Core/InhabitedEnum.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingSingleTypeNamespaceVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingSingleTypeNamespaceMessage: Swift::String =
    "[single type namespace] [API-NAME-001a]: caseless-enum namespace "
    + "contains exactly one nested type — that's a *variant label*, "
    + "not a namespace. Promote the inner type and nest the label "
    + "under its parent: `extension <InnerType> { public struct <Label> "
    + "{ ... } }`."

internal final class NamingSingleTypeNamespaceVisitor: SyntaxVisitor {
    private enum Category {
        case enumCase
        case typeDecl
        case typealiasDecl
        case other
    }

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

    private static func categorize(_ decl: DeclSyntax) -> Category {
        if decl.is(EnumCaseDeclSyntax.self) { return .enumCase }
        if decl.is(StructDeclSyntax.self) { return .typeDecl }
        if decl.is(ClassDeclSyntax.self) { return .typeDecl }
        if decl.is(EnumDeclSyntax.self) { return .typeDecl }
        if decl.is(ActorDeclSyntax.self) { return .typeDecl }
        if decl.is(ProtocolDeclSyntax.self) { return .typeDecl }
        if decl.is(TypeAliasDeclSyntax.self) { return .typealiasDecl }
        return .other
    }

    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        var typeCount = 0
        var hasOther = false
        for member in node.memberBlock.members {
            let category = Self.categorize(member.decl)
            switch category {
            case .enumCase:
                return .visitChildren

            case .typeDecl:
                typeCount += 1

            case .typealiasDecl:
                continue

            case .other:
                hasOther = true
            }
        }
        guard !hasOther else { return .visitChildren }
        guard typeCount == 1 else { return .visitChildren }
        let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "single type namespace",
                message: namingSingleTypeNamespaceMessage
            )
        )
        return .visitChildren
    }
}
