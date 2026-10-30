public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `unknown default` = Lint.Rule(
        id: "unknown default",
        default: .warning,
        controls: [
            .init(
                id: "unknown default annotated",
                source: "func classify(value: Value) { switch value { case .byte: break; @unknown default: break } }",
                path: "Sources/Idiom Core/UnknownDefault.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unknown default explicit cases",
                source: "func classify(value: Value) { switch value { case .byte: break; case .other: break } }",
                path: "Sources/Idiom Core/ExplicitCases.swift",
                expectation: .clean
            ),
            .init(
                id: "unknown default plain",
                source: "func classify(value: Value) { switch value { case .byte: break; default: break } }",
                path: "Sources/Idiom Core/PlainDefault.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = IdiomUnknownDefaultVisitor(
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
internal let idiomUnknownDefaultMessage: Swift::String =
    "[unknown default]: handle new enum cases explicitly instead of "
    + "adding `@unknown default` — the compile-time missed-case signal is "
    + "the asset, and `@unknown default` trades it for a runtime "
    + "fallthrough."

internal final class IdiomUnknownDefaultVisitor: SyntaxVisitor {
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

    private func isWildcard(_ pattern: PatternSyntax) -> Swift::Bool {
        if pattern.is(WildcardPatternSyntax.self) { return true }
        if let expressionPattern = pattern.as(ExpressionPatternSyntax.self) {
            return expressionPattern.expression.is(DiscardAssignmentExprSyntax.self)
        }
        return false
    }

    private func isDefaultLikeLabel(_ label: SwitchCaseSyntax.Label) -> Swift::Bool {
        if case .default = label { return true }
        if case .case(let caseLabel) = label {
            return caseLabel.caseItems.allSatisfy { isWildcard($0.pattern) }
        }
        return false
    }

    override func visit(_ node: SwitchCaseSyntax) -> SyntaxVisitorContinueKind {
        guard
            let attribute = node.attribute,
            attribute.attributeName.trimmedDescription == "unknown",
            isDefaultLikeLabel(node.label)
        else {
            return .visitChildren
        }
        let location = converter.location(for: attribute.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "unknown default",
                message: idiomUnknownDefaultMessage
            )
        )
        return .visitChildren
    }
}
