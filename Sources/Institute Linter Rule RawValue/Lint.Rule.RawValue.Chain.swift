public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `chained rawvalue access` = Lint.Rule(
        id: "chained rawvalue access",
        default: .warning,
        controls: [
            .init(
                id: "chained rawvalue access member chain",
                source: "let normalized = value.rawValue.lowercased()",
                path: "Sources/Raw Value Core/ChainedAccess.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "chained rawvalue access terminal access",
                source: "let raw = value.rawValue",
                path: "Sources/Raw Value Core/TerminalAccess.swift",
                expectation: .clean
            ),
            .init(
                id: "chained rawvalue access string boundary",
                source: #"let example = "value.rawValue.lowercased()""#,
                path: "Tests/Raw Value Tests/ChainExample.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            if Lint.Brand.owned(Lint.Brand.vocabulary, in: source) { return [] }
            let visitor = RawValueChainVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let chainedRawvalueAccessMessage: Swift::String =
    "[chained rawvalue access] [CONV-016]: chaining `.rawValue.method()` (or "
    + "paren-wrapped `(x.rawValue).method()`, which is semantically identical) escapes "
    + "the typed system. Prefer `.retag()` (Tier 1) / `.map()` (Tier 2) / `Type.min(a, b)` "
    + "/ a typed accessor exposed by the wrapper, per [INFRA-103]. If the wrapper IS "
    + "what this site implements (typed-system bottom-out), escalate to supervisor and "
    + "apply `// swift-linter:disable:next chained rawvalue access  // reason: <citation>`."

internal final class RawValueChainVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        guard let base = node.base else { return .visitChildren }
        let unwrapped = Self.peelParens(base)
        guard let baseAccess = unwrapped.as(MemberAccessExprSyntax.self),
            baseAccess.declName.baseName.text == "rawValue"
        else { return .visitChildren }
        let token = node.declName.baseName
        let location = converter.location(for: token.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "chained rawvalue access",
                message: chainedRawvalueAccessMessage
            )
        )
        return .visitChildren
    }

    private static func peelParens(_ expr: ExprSyntax) -> ExprSyntax {
        var current = expr
        while true {
            if let tuple = current.as(TupleExprSyntax.self),
                tuple.elements.count == 1,
                let only = tuple.elements.first?.expression,
                tuple.elements.first?.label == nil
            {
                current = only
                continue
            }
            if let optionalChain = current.as(OptionalChainingExprSyntax.self) {
                current = optionalChain.expression
                continue
            }
            if let forceUnwrap = current.as(ForceUnwrapExprSyntax.self) {
                current = forceUnwrap.expression
                continue
            }
            break
        }
        return current
    }
}
