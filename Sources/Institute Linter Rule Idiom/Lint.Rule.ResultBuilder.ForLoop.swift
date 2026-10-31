public import Lint
internal import SwiftSyntax

extension Lint.Rule {

    public static let `for loop in result builder` = Lint.Rule.`for loop in result builder`(
        allowlist: `result builder for loop default allowlist`
    )

    public static func `for loop in result builder`(
        allowlist: Set<Swift::String>
    ) -> Lint.Rule {
        Lint.Rule(
            id: "for loop in result builder",
            default: .warning,
            controls: [
                .init(
                    id: "for loop in result builder array",
                    source: """
                        let values = Array<Int> {
                          for value in 0..<100 {
                            value
                          }
                        }
                        """,
                    path: "Controls/ForLoopInResultBuilder.swift",
                    expectation: .findings(1)
                )
            ],
            observe: Lint.Rule.measured { source, severity in
                let visitor = ResultBuilderForLoopVisitor(
                    source: source.file,
                    severity: severity,
                    allowlist: allowlist,
                    converter: source.converter
                )
                visitor.walk(source.tree)
                return visitor.matches
            }
        )
    }
}

public let `result builder for loop default allowlist`: Set<Swift::String> = [

    "Array",
    "Swift.Array",
    "ContiguousArray",
    "Swift.ContiguousArray",
    "ArraySlice",
    "Swift.ArraySlice",
    "Set",
    "Swift.Set",
    "Dictionary",
    "Swift.Dictionary",

    "Buffer.Linear",
    "Buffer.Ring",
    "List.Linked",
    "Stack",
    "Queue",
    "Queue.Linked",
    "Heap",
    "Set.Ordered",
    "Bitset",
    "Dictionary.Ordered",
    "Tree.Binary",
    "Tree.Unbounded",
    "Tree.N",
]

@usableFromInline
internal let `result builder for loop message`: Swift::String =
    "[for loop in result builder] [PATTERN-063]: "
    + "`for`-loop in result-builder body materializes a fresh [Element] per "
    + "iteration (12-44x slower than imperative under SE-0289). Write the sequence "
    + "directly: `Builder { 0..<N }` instead of `Builder { for i in 0..<N { i } }`. "
    + "See swift-institute/Research/result-builder-performance-optimization.md for "
    + "the full design rationale. If iteration is genuinely required, escalate to "
    + "supervisor and apply "
    + "`// swift-linter:disable:next for loop in result builder` with a "
    + "`// REASON: <citation>` continuation."

internal final class ResultBuilderForLoopVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let allowlist: Set<Swift::String>
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        allowlist: Set<Swift::String>,
        converter: SourceLocationConverter
    ) {
        self.source = source
        self.severity = severity
        self.allowlist = allowlist
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let identifier = Self.callee(of: node.calledExpression) else {
            return .visitChildren
        }
        guard allowlist.contains(identifier) else {
            return .visitChildren
        }

        if let trailing = node.trailingClosure,
            Self.hasForLoop(in: trailing.statements)
        {
            emit(at: trailing.leftBrace.positionAfterSkippingLeadingTrivia)
        }

        for argument in node.arguments {
            if let closure = argument.expression.as(ClosureExprSyntax.self),
                Self.hasForLoop(in: closure.statements)
            {
                emit(at: closure.leftBrace.positionAfterSkippingLeadingTrivia)
            }
        }
        return .visitChildren
    }

    private func emit(at position: AbsolutePosition) {
        let location = converter.location(for: position)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "for loop in result builder",
                message: `result builder for loop message`
            )
        )
    }

    @usableFromInline
    static func hasForLoop(in statements: CodeBlockItemListSyntax) -> Bool {
        let detector = ResultBuilderForLoopForInDetector()
        detector.walk(statements)
        return detector.found
    }

    @usableFromInline
    static func callee(of expression: ExprSyntax) -> Swift::String? {
        if let memberAccess = expression.as(MemberAccessExprSyntax.self) {
            guard let base = memberAccess.base else {
                return nil
            }
            guard let baseIdentifier = callee(of: base) else {
                return nil
            }
            return baseIdentifier + "." + memberAccess.declName.baseName.text
        }
        if let genericSpec = expression.as(GenericSpecializationExprSyntax.self) {
            return callee(of: genericSpec.expression)
        }
        if let declRef = expression.as(DeclReferenceExprSyntax.self) {
            return declRef.baseName.text
        }
        return nil
    }
}
