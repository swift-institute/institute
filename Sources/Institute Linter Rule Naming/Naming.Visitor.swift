internal import SwiftSyntax

extension Naming {
    internal enum Visitor {}
}

extension Naming.Visitor {
    @usableFromInline
    internal static let family: Swift::Set<Swift::String> = [
        "SyntaxVisitor",
        "SyntaxAnyVisitor",
        "SyntaxRewriter",
    ]

    internal static func extends(_ clause: InheritanceClauseSyntax?) -> Swift::Bool {
        guard let clause else { return false }
        for inherited in clause.inheritedTypes {
            let type = inherited.type
            let leaf: Swift::String? =
                if let identifier = type.as(IdentifierTypeSyntax.self) {
                    identifier.name.text
                } else if let member = type.as(MemberTypeSyntax.self) {
                    member.name.text
                } else {
                    nil
                }
            if let leaf, family.contains(leaf) {
                return true
            }
        }
        return false
    }

    internal static func inheritanceLeaves(_ clause: InheritanceClauseSyntax?) -> [Swift::String] {
        guard let clause else { return [] }
        var names: [Swift::String] = []
        for inherited in clause.inheritedTypes {
            let type = inherited.type.as(AttributedTypeSyntax.self)?.baseType ?? inherited.type
            if let identifier = type.as(IdentifierTypeSyntax.self) {
                names.append(identifier.name.text)
            } else if let member = type.as(MemberTypeSyntax.self) {
                names.append(member.name.text)
            }
        }
        return names
    }
}
