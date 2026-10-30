internal import SwiftSyntax

internal final class ThrowsClosureTryFinder: SyntaxVisitor {
    var found = false
    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.questionOrExclamationMark == nil else {
            return .visitChildren
        }
        if !throwsClosureTryIsInsideMaterializingDoCatch(Syntax(node)) {
            found = true
        }
        return .skipChildren
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
}
