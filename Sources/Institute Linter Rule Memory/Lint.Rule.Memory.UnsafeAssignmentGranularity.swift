public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `unsafe assignment granularity` = Lint.Rule(
        id: "unsafe assignment granularity",
        default: .warning,
        controls: [
            .init(
                id: "unsafe assignment granularity rhs only",
                source: "func store() { pointer.pointee = unsafe other.pointee }",
                path: "Sources/Memory Core/UnsafeAssignmentRHS.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unsafe assignment granularity whole expression",
                source: "func store() { unsafe (pointer.pointee = other.pointee) }",
                path: "Sources/Memory Core/UnsafeAssignmentWhole.swift",
                expectation: .clean
            ),
            .init(
                id: "unsafe assignment granularity safe destination",
                source: "func load() { count = unsafe pointer.pointee }",
                path: "Sources/Memory Core/UnsafeLoad.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = MemoryUnsafeAssignmentGranularityVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let memoryUnsafeAssignmentGranularityMessage: Swift::String =
    "[unsafe assignment granularity] [PATTERN-005b]/[MEM-SAFE-002]: "
    + "`<lvalue> = unsafe <expr>` marks only the RHS as unsafe, and `<lvalue>` "
    + "is itself an unsafe destination (a `.pointee` store, a pointer "
    + "subscript, or an already `unsafe`-marked sub-expression) — the "
    + "assignment to `<lvalue>` is uncovered. Wrap the entire "
    + "expression: `unsafe (<lvalue> = <expr>)`. Each unsafe operation "
    + "requires its own `unsafe` acknowledgment; expression granularity."

internal func memoryUnsafeAssignmentGranularityLHSIsUnsafeDestination(
    _ lhs: ExprSyntax
) -> Swift::Bool {
    let finder = MemoryUnsafeAssignmentLHSFinder(viewMode: .sourceAccurate)
    finder.walk(lhs)
    return finder.isUnsafeDestination
}

private final class MemoryUnsafeAssignmentLHSFinder: SyntaxVisitor {
    var isUnsafeDestination = false

    override func visit(_ node: UnsafeExprSyntax) -> SyntaxVisitorContinueKind {
        isUnsafeDestination = true
        return .skipChildren
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if node.declName.baseName.text == "pointee" {
            isUnsafeDestination = true
            return .skipChildren
        }
        return .visitChildren
    }

    override func visit(_ node: SubscriptCallExprSyntax) -> SyntaxVisitorContinueKind {
        let baseText = node.calledExpression.trimmedDescription.lowercased()
        if baseText.contains("pointer") || baseText.contains("unsafe") {
            isUnsafeDestination = true
            return .skipChildren
        }
        return .visitChildren
    }
}
