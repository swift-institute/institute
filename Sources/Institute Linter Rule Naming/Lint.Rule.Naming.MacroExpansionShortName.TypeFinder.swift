internal import SwiftSyntax

internal final class NamingMacroExpansionShortNameTypeFinder: SyntaxVisitor {
    var matches: [Swift::String] = []
    private var genericParameters: Swift::Set<Swift::String> = []

    override func visit(_ node: GenericParameterSyntax) -> SyntaxVisitorContinueKind {
        genericParameters.insert(node.name.text)
        return .visitChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        let name = node.name.text
        if name == "Self" || name == "__macro_interpolation__" {
            return .visitChildren
        }
        if genericParameters.contains(name) {
            return .visitChildren
        }
        if let member = node.parent?.as(MemberTypeSyntax.self),
            member.baseType.id == node.id
        {
            return .visitChildren
        }
        matches.append(name)
        return .visitChildren
    }
}
