internal import SwiftSyntax

internal final class ThrowsPhantomGenericDeclCollector: SyntaxVisitor {
    var generics: [Swift::String: [Swift::String]] = [:]

    init() { super.init(viewMode: .sourceAccurate) }

    override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.genericParameterClause)
        return .visitChildren
    }
    override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.genericParameterClause)
        return .visitChildren
    }
    override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.genericParameterClause)
        return .visitChildren
    }
    override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
        record(node.name.text, node.genericParameterClause)
        return .visitChildren
    }

    private func record(_ name: Swift::String, _ clause: GenericParameterClauseSyntax?) {
        let parameters = throwsPhantomGenericParameterNames(clause)
        if !parameters.isEmpty { generics[name] = parameters }
    }
}
