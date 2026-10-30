internal import SwiftSyntax

internal final class PlatformSwiftQualificationRewriter: SyntaxRewriter {
    var changed: Swift::Bool = false

    private let declared: Swift::Set<Swift::String>

    init(declared: Swift::Set<Swift::String>) {
        self.declared = declared
        super.init()
    }

    private func qualify(_ type: TypeSyntax, at node: Syntax) -> TypeSyntax? {
        guard !platformSwiftQualificationIsInsideStdlibExtension(node) else { return nil }
        guard let qualified = platformSwiftQualificationQualified(type, declared: declared) else {
            return nil
        }
        changed = true
        return qualified
    }

    override func visit(_ node: InheritedTypeSyntax) -> InheritedTypeSyntax {
        guard let qualified = qualify(node.type, at: Syntax(node)) else {
            return super.visit(node)
        }
        return node.with(\.type, qualified)
    }

    override func visit(_ node: GenericParameterSyntax) -> GenericParameterSyntax {
        guard let inherited = node.inheritedType,
            let qualified = qualify(inherited, at: Syntax(node))
        else {
            return super.visit(node)
        }
        return node.with(\.inheritedType, qualified)
    }

    override func visit(_ node: ConformanceRequirementSyntax) -> ConformanceRequirementSyntax {
        guard let qualified = qualify(node.rightType, at: Syntax(node)) else {
            return super.visit(node)
        }
        return node.with(\.rightType, qualified)
    }

    override func visit(_ node: SomeOrAnyTypeSyntax) -> TypeSyntax {
        guard let qualified = qualify(node.constraint, at: Syntax(node)) else {
            return super.visit(node)
        }
        return TypeSyntax(node.with(\.constraint, qualified))
    }
}
