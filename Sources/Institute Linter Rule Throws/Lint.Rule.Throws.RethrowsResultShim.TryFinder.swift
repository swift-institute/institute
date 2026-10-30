internal import SwiftSyntax

internal final class ThrowsRethrowsTryFinder: SyntaxVisitor {
    var positions: [AbsolutePosition] = []
    var closureDepth: Swift::Int = -1
    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        guard node.questionOrExclamationMark == nil else {
            return .visitChildren
        }
        if throwsClosureTryIsInsideMaterializingDoCatch(Syntax(node)) {
            return .visitChildren
        }
        positions.append(node.tryKeyword.positionAfterSkippingLeadingTrivia)
        return .visitChildren
    }
    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        closureDepth += 1
        if closureDepth > 0 { return .skipChildren }
        return .visitChildren
    }
    override func visitPost(_: ClosureExprSyntax) { closureDepth -= 1 }
    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind { return .skipChildren }
}
