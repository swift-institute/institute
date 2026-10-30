internal import SwiftSyntax

internal final class MemoryExtensionPackExpansionFinder: SyntaxVisitor {
    var found = false
    override func visit(_ node: PackExpansionTypeSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
    override func visit(_ node: PackElementTypeSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
}
