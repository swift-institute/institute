public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `typed throws cannot use self error` = Lint.Rule(
        id: "typed throws cannot use self error",
        default: .error,
        controls: [
            .init(
                id: "typed throws cannot use self error unresolved protocol",
                source: "protocol Reader { func read() throws(Self.Error) }",
                path: "Sources/Throws Consumer/UnresolvedSelfError.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "typed throws cannot use self error associated type",
                source: "protocol Reader { associatedtype Error: Swift.Error; "
                    + "func read() throws(Self.Error) }",
                path: "Sources/Throws Consumer/AssociatedSelfError.swift",
                expectation: .clean
            ),
            .init(
                id: "typed throws cannot use self error concrete type",
                source: "struct Reader { enum Error: Swift.Error { case invalid }; "
                    + "func read() throws(Self.Error) {} }",
                path: "Sources/Throws Consumer/ConcreteSelfError.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsSelfErrorInTypedThrowsVisitor(
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
internal let throwsSelfErrorInTypedThrowsMessage: Swift::String =
    "[typed throws cannot use self error] [API-ERR-002]: `throws(Self.Error)` "
    + "inside a protocol only resolves when the protocol declares "
    + "`associatedtype Error`. Add `associatedtype Error: Swift.Error` to this "
    + "protocol, or reference a concrete nested error type instead of "
    + "`Self.Error`."

internal final class ThrowsSelfErrorInTypedThrowsVisitor: SyntaxVisitor {
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

    override func visit(_ node: ThrowsClauseSyntax) -> SyntaxVisitorContinueKind {
        guard let typed = node.type else { return .visitChildren }
        guard isSelfError(typed) else { return .visitChildren }
        guard shouldFlag(Syntax(node)) else { return .visitChildren }
        let location = converter.location(for: typed.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "typed throws cannot use self error",
                message: throwsSelfErrorInTypedThrowsMessage
            )
        )
        return .visitChildren
    }

    private func isSelfError(_ type: TypeSyntax) -> Swift::Bool {
        guard let member = type.as(MemberTypeSyntax.self),
            member.name.text == "Error",
            let base = member.baseType.as(IdentifierTypeSyntax.self),
            base.name.text == "Self"
        else { return false }
        return true
    }

    private func shouldFlag(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        while let parent = current {
            if let proto = parent.as(ProtocolDeclSyntax.self) {
                return !declaresAssociatedError(proto)
            }
            if parent.is(StructDeclSyntax.self)
                || parent.is(ClassDeclSyntax.self)
                || parent.is(EnumDeclSyntax.self)
                || parent.is(ActorDeclSyntax.self)
                || parent.is(ExtensionDeclSyntax.self)
            {
                return false
            }
            current = parent.parent
        }
        return false
    }

    private func declaresAssociatedError(_ proto: ProtocolDeclSyntax) -> Swift::Bool {
        for member in proto.memberBlock.members {
            if let associated = member.decl.as(AssociatedTypeDeclSyntax.self),
                associated.name.text == "Error"
            {
                return true
            }
        }
        return false
    }
}
