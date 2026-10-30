internal import SwiftSyntax

internal final class ThrowsExistentialRequireMacroFinder: SyntaxVisitor {
    var found: Swift::Bool = false

    override func visit(_ node: MacroExpansionExprSyntax) -> SyntaxVisitorContinueKind {
        if node.macroName.text == "require" {
            found = true
            return .skipChildren
        }
        return .visitChildren
    }
}
