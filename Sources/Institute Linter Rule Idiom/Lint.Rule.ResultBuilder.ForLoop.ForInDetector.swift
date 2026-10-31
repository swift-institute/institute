internal import SwiftSyntax

internal final class ResultBuilderForLoopForInDetector: SyntaxVisitor {
    var found = false

    init() {
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: ForStmtSyntax) -> SyntaxVisitorContinueKind {
        found = true
        return .skipChildren
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {

        .skipChildren
    }
}
