package import Lint
package import Linter_Rule_Scope
internal import Linter_Rule_SwiftUI
package import SwiftSyntax

extension Lint.Feature {

    package enum Kind: Sendable, Hashable {
        case userDefaults
        case withAnimation
    }

    package struct Hit {
        package let node: Syntax
        package let kind: Kind
        package let detail: Swift::String
    }

    package final class Visitor: SyntaxVisitor {

        let index: Lint.Scope.Index
        let target: Swift::Bool
        var frames: [Swift::Bool] = []
        package var hits: [Hit] = []

        package init(index: Lint.Scope.Index, target: Swift::Bool) {
            self.index = index
            self.target = target
            super.init(viewMode: .sourceAccurate)
        }

        var inScope: Swift::Bool { target || frames.contains(true) }

        func hit(_ node: some SyntaxProtocol, _ kind: Kind, _ detail: Swift::String) {
            guard inScope else { return }
            hits.append(Hit(node: Syntax(node), kind: kind, detail: detail))
        }

        func enter(_ node: some DeclSyntaxProtocol, attributes: AttributeListSyntax, extending: Swift::Bool) {
            let name = Lint.Scope.Declaration.qualified(type: Syntax(node)) ?? ""
            frames.append(
                Lint.Scope.Index.attributed(attributes, ["Feature"])
                    || (extending && Lint.Scope.Index.matches(name, in: index.features))
            )
        }

        package override func visit(_ node: StructDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, attributes: node.attributes, extending: false)
            return .visitChildren
        }

        package override func visitPost(_ node: StructDeclSyntax) { frames.removeLast() }

        package override func visit(_ node: ClassDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, attributes: node.attributes, extending: false)
            return .visitChildren
        }

        package override func visitPost(_ node: ClassDeclSyntax) { frames.removeLast() }

        package override func visit(_ node: EnumDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, attributes: node.attributes, extending: false)
            return .visitChildren
        }

        package override func visitPost(_ node: EnumDeclSyntax) { frames.removeLast() }

        package override func visit(_ node: ActorDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, attributes: node.attributes, extending: false)
            return .visitChildren
        }

        package override func visitPost(_ node: ActorDeclSyntax) { frames.removeLast() }

        package override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
            enter(node, attributes: node.attributes, extending: true)
            return .visitChildren
        }

        package override func visitPost(_ node: ExtensionDeclSyntax) { frames.removeLast() }

        package override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
            if Lint.SwiftUI.Expression.isWithAnimation(node) {
                hit(node, .withAnimation, "`withAnimation` call")
            }
            return .visitChildren
        }

        package override func visit(_ node: DeclReferenceExprSyntax) -> SyntaxVisitorContinueKind {
            if node.baseName.text == "UserDefaults" {
                hit(node, .userDefaults, "`UserDefaults`")
            }
            return .visitChildren
        }

        package override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
            if node.name.text == "UserDefaults" {
                hit(node, .userDefaults, "`UserDefaults`")
            }
            return .visitChildren
        }

        package override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
            if Lint.Scope.Declaration.leaf(node.attributeName) == "AppStorage" {
                hit(node, .userDefaults, "`@AppStorage`")
            }
            return .visitChildren
        }

        package override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
            if node.declName.baseName.text == "appStorage" {
                hit(node, .userDefaults, "`.appStorage` key")
            }
            return .visitChildren
        }
    }
}
