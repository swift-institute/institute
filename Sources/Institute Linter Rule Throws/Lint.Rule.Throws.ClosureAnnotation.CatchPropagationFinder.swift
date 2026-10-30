internal import SwiftSyntax

internal final class ThrowsClosureCatchPropagationFinder: SyntaxVisitor {
    var foundPropagation = false
    override func visit(_: ThrowStmtSyntax) -> SyntaxVisitorContinueKind {
        foundPropagation = true
        return .skipChildren
    }
    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        if node.questionOrExclamationMark == nil {
            foundPropagation = true
        }
        return .skipChildren
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
}
