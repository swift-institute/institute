internal import SwiftSyntax

/// An attribute the compiler defines, such as `@storageRestrictions`, `@inlinable` or `@_spi`, starts lowercase or
/// with an underscore and cannot be qualified, so its name is no type reference; an attribute naming a macro or a
/// property wrapper is one (swift-institute/Issues#276).
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
        if let attribute = node.parent?.as(AttributeSyntax.self),
            attribute.attributeName.id == node.id,
            name.first?.isUppercase != true
        {
            return .visitChildren
        }
        matches.append(name)
        return .visitChildren
    }
}
