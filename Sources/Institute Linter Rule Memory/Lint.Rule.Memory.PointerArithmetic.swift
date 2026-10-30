public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `pointer advanced by` = Lint.Rule(
        id: "pointer advanced by",
        default: .warning,
        controls: [
            .init(
                id: "pointer advanced by unsafe",
                source: "func advance(_ pointer: UnsafePointer<Int>, by offset: Int) { _ = unsafe pointer.advanced(by: offset) }",
                path: "Sources/Memory Core/UnsafePointerAdvance.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "pointer advanced by strideable",
                source: "func advance(_ value: Int) { _ = value.advanced(by: 1) }",
                path: "Sources/Memory Core/StrideableAdvance.swift",
                expectation: .clean
            ),
            .init(
                id: "pointer advanced by test fixture",
                source: "func advance(_ pointer: UnsafePointer<Int>, by offset: Int) { _ = unsafe pointer.advanced(by: offset) }",
                path: "Tests/Memory Tests/UnsafePointerAdvance.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if Lint.Brand.owned(Lint.Brand.vocabulary, in: source) { return [] }
            let path = source.file.filePath
            for excluded in ["Tests", "Experiments", "Examples"] {
                if path == excluded
                    || path.hasPrefix("\(excluded)/")
                    || path.contains("/\(excluded)/")
                {
                    return []
                }
            }
            let visitor = MemoryPointerArithmeticVisitor(
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
internal let memoryPointerArithmeticMessage: Swift::String =
    "[pointer advanced by] [MEM-SPAN-003]: raw pointer arithmetic via "
    + "`unsafe …advanced(by:)` is mechanism. Prefer the Span family: `.span` "
    + "(read the initialised region), `.mutableSpan` (mutate it in place), or "
    + "`.withOutputSpan(addingCapacity:)` (append into the uninitialised tail) "
    + "per [MEM-SPAN-003]/[MEM-SAFE-012]. A raw `Unsafe*Pointer` is the last "
    + "resort per [MEM-SAFE-015]: when one is genuinely required (C / FFI, or "
    + "move-out semantics `MutableSpan` cannot express), keep it `unsafe` and "
    + "add an adjacent `// SAFETY:` or `// WHY:` justification on the enclosing "
    + "statement — that documents the last-resort site and clears this warning. "
    + "(`Strideable.advanced(by:)` for range / index iteration is not pointer "
    + "arithmetic and is not flagged.)"

internal final class MemoryPointerArithmeticVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(source: Source.File, severity: Diagnostic.Severity, converter: SourceLocationConverter) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self) else {
            return .visitChildren
        }
        guard member.declName.baseName.text == "advanced" else {
            return .visitChildren
        }
        guard node.arguments.count == 1,
            let argument = node.arguments.first,
            argument.label?.text == "by"
        else {
            return .visitChildren
        }
        guard isWithinUnsafeExpression(Syntax(node)) else {
            return .visitChildren
        }
        if hasAdjacentLastResortJustification(Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(
            for: member.declName.baseName.positionAfterSkippingLeadingTrivia
        )
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "pointer advanced by",
                message: memoryPointerArithmeticMessage
            )
        )
        return .visitChildren
    }

    private func isWithinUnsafeExpression(_ node: Syntax) -> Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if candidate.is(UnsafeExprSyntax.self) { return true }
            if candidate.is(CodeBlockItemSyntax.self)
                || candidate.is(MemberBlockItemSyntax.self)
            {
                return false
            }
            current = candidate.parent
        }
        return false
    }

    private func hasAdjacentLastResortJustification(_ node: Syntax) -> Bool {
        var current: Syntax? = node
        while let candidate = current {
            if let item = candidate.as(CodeBlockItemSyntax.self) {
                return hasAdjacentJustificationComment(item.leadingTrivia)
            }
            if let member = candidate.as(MemberBlockItemSyntax.self) {
                return hasAdjacentJustificationComment(member.leadingTrivia)
            }
            current = candidate.parent
        }
        return false
    }

    private func hasAdjacentJustificationComment(_ trivia: Trivia) -> Bool {
        memoryTriviaHasAdjacentComment(trivia) { body in
            body.hasPrefix("SAFETY:") || body.hasPrefix("WHY:")
        }
    }
}
