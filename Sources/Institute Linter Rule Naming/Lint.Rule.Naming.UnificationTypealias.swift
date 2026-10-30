public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `unification typealias` = Lint.Rule(
        id: "unification typealias",
        default: .warning,
        controls: [
            .init(
                id: "unification typealias associated type witness",
                source: "public protocol Keyed { associatedtype HandlerKey }\n"
                    + "public struct Sample: Keyed {}\n"
                    + "extension Sample { public typealias HandlerKey = Handler.Key }",
                path: "Sources/Naming Core/Witness.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias same name without a requirement",
                source: "public protocol Keyed { associatedtype Other }\n"
                    + "public struct Sample: Keyed {}\n"
                    + "extension Sample { public typealias HandlerKey = Handler.Key }",
                path: "Sources/Naming Core/Witness.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias different leaf",
                source: "public typealias SourceLocation = Text.Location",
                path: "Sources/Naming Core/DifferentLeaf.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias same leaf",
                source: "public typealias Event = Kernel.Event",
                path: "Sources/Naming Core/SameLeaf.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias case-only leaf",
                source: "public typealias sRGB = IEC_61966.`2`.`1`.SRGB",
                path: "Sources/Naming Core/CaseOnlyLeaf.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias quoted case-only leaf",
                source: "private typealias `event` = Kernel.Event",
                path: "Sources/Naming Core/QuotedCaseOnlyLeaf.swift",
                expectation: .clean
            ),
            .init(
                id: "unification typealias different letters",
                source: "public typealias sRGB = Color.SRGBA",
                path: "Sources/Naming Core/DifferentLetters.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias different underscore",
                source: "public typealias SR_GB = Color.SRGB",
                path: "Sources/Naming Core/DifferentUnderscore.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unification typealias swift bridge",
                source: "public typealias Protocol = Swift.Equatable",
                path: "Sources/Naming Core/SwiftBridge.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingUnificationTypealiasVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                index: source.index
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingUnificationTypealiasMessage: Swift::String =
    "[unification typealias] [API-NAME-004]: typealias renames a "
    + "member type to a different local name. Type unification MUST use the "
    + "canonical type at all call sites; a typealias bridge adds indirection "
    + "without domain value."

internal final class NamingUnificationTypealiasVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    let index: Lint.Source.Index
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter,
        index: Lint.Source.Index
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        self.index = index
        super.init(viewMode: .sourceAccurate)
    }

    private func enclosingTypeName(of node: Syntax) -> Swift::String? {
        var current = node.parent
        while let candidate = current {
            if let decl = candidate.as(ExtensionDeclSyntax.self) {
                return decl.extendedType.trimmedDescription
            }
            if let decl = candidate.as(StructDeclSyntax.self) { return decl.name.text }
            if let decl = candidate.as(EnumDeclSyntax.self) { return decl.name.text }
            if let decl = candidate.as(ClassDeclSyntax.self) { return decl.name.text }
            if let decl = candidate.as(ActorDeclSyntax.self) { return decl.name.text }
            current = candidate.parent
        }
        return nil
    }

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        let lhsName = node.name.text
        guard let member = node.initializer.value.as(MemberTypeSyntax.self) else {
            return .visitChildren
        }
        if member.genericArgumentClause != nil { return .visitChildren }
        let rhsLeaf = member.name.text
        guard
            Lint.Syntax.Identifier.unescaped(rhsLeaf).lowercased()
                != Lint.Syntax.Identifier.unescaped(lhsName).lowercased()
        else { return .visitChildren }
        if let baseIdentifier = member.baseType.as(IdentifierTypeSyntax.self),
            baseIdentifier.name.text == "Swift"
        {
            return .visitChildren
        }
        if Naming.isInsideConformingContext(Syntax(node)) {
            return .visitChildren
        }
        if let owner = enclosingTypeName(of: Syntax(node)),
            index.witnessesAssociatedType(named: lhsName, on: owner)
        {
            return .visitChildren
        }
        if Naming.isProtocolSentinel(rhsLeaf) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.typealiasKeyword.positionAfterSkippingLeadingTrivia
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
                identifier: "unification typealias",
                message: namingUnificationTypealiasMessage
            )
        )
        return .visitChildren
    }
}
