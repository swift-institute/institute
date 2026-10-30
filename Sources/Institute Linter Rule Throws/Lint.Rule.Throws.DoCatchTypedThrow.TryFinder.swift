internal import SwiftSyntax

internal final class ThrowsDoCatchTypedThrowTryFinder: SyntaxVisitor {
    var found = false
    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.questionOrExclamationMark == nil else {
            return .visitChildren
        }
        found = true
        return .skipChildren
    }
    override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}
