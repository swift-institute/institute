internal import SwiftSyntax

internal final class MemoryBorrowingSelfShortCircuitFinder: SyntaxVisitor {
    let borrowingSelfNames: Swift::Set<Swift::String>
    var positions: [AbsolutePosition] = []

    init(viewMode: SyntaxTreeViewMode, borrowingSelfNames: Swift::Set<Swift::String>) {
        self.borrowingSelfNames = borrowingSelfNames
        super.init(viewMode: viewMode)
    }

    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        var shortCircuitPositions: [AbsolutePosition] = []
        for element in node.elements {
            guard let op = element.as(BinaryOperatorExprSyntax.self) else { continue }
            if op.operator.text == "&&" || op.operator.text == "||" {
                shortCircuitPositions.append(op.operator.positionAfterSkippingLeadingTrivia)
            }
        }
        guard !shortCircuitPositions.isEmpty else { return .visitChildren }
        var anyOperandIsBorrowingSelf = false
        for element in node.elements {
            if element.is(BinaryOperatorExprSyntax.self) { continue }
            if rootIdentifierIsBorrowingSelf(element) {
                anyOperandIsBorrowingSelf = true
                break
            }
        }
        if anyOperandIsBorrowingSelf {
            positions.append(contentsOf: shortCircuitPositions)
        }
        return .visitChildren
    }

    private func rootIdentifierIsBorrowingSelf(_ node: some SyntaxProtocol) -> Swift::Bool {
        if let decl = node.as(DeclReferenceExprSyntax.self) {
            return borrowingSelfNames.contains(decl.baseName.text)
        }
        if let member = node.as(MemberAccessExprSyntax.self) {
            if let base = member.base {
                return rootIdentifierIsBorrowingSelf(base)
            }
            return false
        }
        if let call = node.as(FunctionCallExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(call.calledExpression)
        }
        if let subscriptCall = node.as(SubscriptCallExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(subscriptCall.calledExpression)
        }
        if let prefix = node.as(PrefixOperatorExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(prefix.expression)
        }
        if let force = node.as(ForceUnwrapExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(force.expression)
        }
        if let chain = node.as(OptionalChainingExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(chain.expression)
        }
        if let tuple = node.as(TupleExprSyntax.self) {
            for element in tuple.elements {
                if rootIdentifierIsBorrowingSelf(element.expression) {
                    return true
                }
            }
            return false
        }
        if let sequence = node.as(SequenceExprSyntax.self) {
            for element in sequence.elements {
                if element.is(BinaryOperatorExprSyntax.self) { continue }
                if rootIdentifierIsBorrowingSelf(element) {
                    return true
                }
            }
            return false
        }
        if let infix = node.as(InfixOperatorExprSyntax.self) {
            return rootIdentifierIsBorrowingSelf(infix.leftOperand)
                || rootIdentifierIsBorrowingSelf(infix.rightOperand)
        }
        return false
    }

    override func visit(_: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }
}
