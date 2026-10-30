internal import SwiftSyntax

internal final class SharedBoxAssignmentFinder: SyntaxVisitor {
    var found = false

    override func visit(_ node: InfixOperatorExprSyntax) -> SyntaxVisitorContinueKind {
        if node.operator.is(AssignmentExprSyntax.self),
            isSelfMember(node.leftOperand), isSharedCall(node.rightOperand)
        {
            found = true
            return .skipChildren
        }
        return .visitChildren
    }

    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Swift::Array(node.elements)
        for index in elements.indices.dropFirst().dropLast() {
            if elements[index].is(AssignmentExprSyntax.self),
                isSelfMember(elements[index - 1]), isSharedCall(elements[index + 1])
            {
                found = true
                return .skipChildren
            }
        }
        return .visitChildren
    }

    private func isSelfMember(_ expression: ExprSyntax) -> Swift::Bool {
        guard let member = expression.as(MemberAccessExprSyntax.self) else { return false }
        return member.base?.as(DeclReferenceExprSyntax.self)?.baseName.text == "self"
    }

    private func isSharedCall(_ expression: ExprSyntax) -> Swift::Bool {
        guard let call = expression.as(FunctionCallExprSyntax.self) else { return false }
        return call.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Shared"
    }
}
