public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `nonisolated unsafe without invariant` = Lint.Rule(
        id: "nonisolated unsafe without invariant",
        default: .warning,
        controls: [
            .init(
                id: "nonisolated unsafe without invariant missing",
                source: "nonisolated(unsafe) let sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)",
                path: "Sources/Memory Core/MissingUnsafeInvariant.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "nonisolated unsafe without invariant documented",
                source: "// SAFETY: Allocated once and never mutated.\nnonisolated(unsafe) let sentinel: UnsafeMutableRawPointer = .allocate(capacity: 0)",
                path: "Sources/Memory Core/DocumentedUnsafeInvariant.swift",
                expectation: .clean
            ),
            .init(
                id: "nonisolated unsafe without invariant isolated",
                source: "let value: Int = 0",
                path: "Sources/Memory Core/IsolatedValue.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = MemoryNonisolatedUnsafeInvariantVisitor(
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
internal let memoryNonisolatedUnsafeInvariantMessage: Swift::String =
    "[nonisolated unsafe without invariant] [MEM-SAFE-025a]: `nonisolated(unsafe)` "
    + "declarations MUST carry an adjacent `// SAFETY:` or `// WHY:` comment "
    + "citing the encapsulation invariant (allocated once / never mutated post-init / "
    + "sync mechanism / ownership discipline). The comment MUST immediately precede "
    + "the declaration with no intervening blank line. Multi-line blocks are accepted "
    + "with the `// SAFETY:` or `// WHY:` prefix on any line of the contiguous block "
    + "(typically the first line); continuation lines need no prefix."

internal final class MemoryNonisolatedUnsafeInvariantVisitor: SyntaxVisitor {
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

    private func hasNonisolatedUnsafe(_ modifiers: DeclModifierListSyntax) -> Bool {
        for modifier in modifiers {
            if modifier.name.tokenKind == .keyword(.nonisolated) {
                if let detail = modifier.detail {
                    if detail.detail.text == "unsafe" {
                        return true
                    }
                }
            }
        }
        return false
    }

    private func hasAdjacentInvariantComment(_ trivia: Trivia) -> Bool {
        memoryTriviaHasAdjacentComment(trivia) { body in
            body.hasPrefix("SAFETY:") || body.hasPrefix("WHY:")
        }
    }

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        guard hasNonisolatedUnsafe(node.modifiers) else {
            return .visitChildren
        }
        let trivia = node.leadingTrivia
        if hasAdjacentInvariantComment(trivia) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.bindingSpecifier.positionAfterSkippingLeadingTrivia
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
                identifier: "nonisolated unsafe without invariant",
                message: memoryNonisolatedUnsafeInvariantMessage
            )
        )
        return .visitChildren
    }
}
