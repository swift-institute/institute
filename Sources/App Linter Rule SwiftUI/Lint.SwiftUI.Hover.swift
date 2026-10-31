internal import Lint
internal import Linter_Rule_SwiftUI
internal import SwiftSyntax

extension Lint.SwiftUI {

    /// The one exception to "a view holds no state" (coenttb-app S3): a modifier named here may keep whether the
    /// pointer is over it, for its own look. SwiftUI on macOS offers no stateless hover; the pointer writes the flag,
    /// it resets itself, and nothing but the modifier's appearance reads it, so no feature or database ever sees it.
    enum Hover {
        /// The modifiers that may hold a hover flag.
        static let modifiers: Swift::Set<Swift::String> = ["Hover"]

        /// Whether `node`, a view-state finding, is that flag: the only `@State` of a `ViewModifier` named in
        /// `modifiers`, declared `private`, one binding, of type `Bool`.
        static func allows(_ node: Syntax) -> Swift::Bool {
            guard let attribute = node.as(AttributeSyntax.self),
                attribute.attributeName.trimmedDescription == "State",
                let variable = attribute.parent?.parent?.as(VariableDeclSyntax.self),
                variable.modifiers.contains(where: { $0.name.tokenKind == .keyword(.private) }),
                variable.bindings.count == 1,
                let binding = variable.bindings.first,
                isBool(binding),
                let modifier = enclosing(variable),
                modifiers.contains(modifier.name.text),
                modifier.inheritanceClause?.inheritedTypes.contains(where: {
                    $0.type.trimmedDescription == "ViewModifier"
                }) == true
            else { return false }
            let states = modifier.memberBlock.members.compactMap { $0.decl.as(VariableDeclSyntax.self) }.filter {
                $0.attributes.contains { $0.as(AttributeSyntax.self)?.attributeName.trimmedDescription == "State" }
            }
            return states.count == 1
        }

        static func isBool(_ binding: PatternBindingSyntax) -> Swift::Bool {
            if let annotation = binding.typeAnnotation { return annotation.type.trimmedDescription == "Bool" }
            return binding.initializer?.value.is(BooleanLiteralExprSyntax.self) == true
        }

        static func enclosing(_ node: some SyntaxProtocol) -> StructDeclSyntax? {
            var parent = node.parent
            while let current = parent {
                if let declaration = current.as(StructDeclSyntax.self) { return declaration }
                parent = current.parent
            }
            return nil
        }
    }
}
