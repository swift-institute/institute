internal import SwiftSyntax

internal final class ThrowsDoCatchThrowFinder: SyntaxVisitor {
    var found = false
    override func visit(_: ThrowStmtSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }
    override func visit(_: DoStmtSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}
