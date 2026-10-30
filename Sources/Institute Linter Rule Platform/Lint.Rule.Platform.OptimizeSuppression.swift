public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `optimize suppression attribute` = Lint.Rule(
        id: "optimize suppression attribute",
        default: .warning,
        controls: [
            .init(
                id: "optimize suppression attribute optimize none",
                source: "@_optimize(none) func run() {}",
                path: "Sources/Platform Core/SuppressedOptimization.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "optimize suppression attribute inline never",
                source: "@inline(never) func run() {}",
                path: "Sources/Platform Core/InlineControl.swift",
                expectation: .clean
            ),
            .init(
                id: "optimize suppression attribute string boundary",
                source: #"let example = "@_optimize(none) func run() {}""#,
                path: "Tests/Platform Tests/OptimizationExample.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = PlatformOptimizeSuppressionVisitor(
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
internal let platformOptimizeSuppressionMessage: Swift::String =
    "[optimize suppression attribute] [ISSUE-008]: optimization-suppression "
    + "attribute (`@_optimize(none)`, `@_optimize(size)`, or "
    + "`@_semantics(\"optimize.no.*\")`) used as a crash-workaround. The "
    + "attribute masks a SIL-optimizer scalability bug AND is itself a "
    + "teardown-miscompile risk in `-O` modules (compiler-bug catalog §A19). "
    + "Remove the workaround attribute. If it must stay, apply "
    + "`// swift-linter:disable:next optimize suppression attribute` with a "
    + "`// REASON: <dossier / catalog-§ citation>` continuation."

internal func platformOptimizeSuppressionSemanticsString(
    _ node: AttributeSyntax
) -> Swift::String? {
    guard case .argumentList(let arguments)? = node.arguments,
        let first = arguments.first,
        let literal = first.expression.as(StringLiteralExprSyntax.self)
    else { return nil }
    var value = ""
    for segment in literal.segments {
        guard let simple = segment.as(StringSegmentSyntax.self) else { return nil }
        value += simple.content.text
    }
    return value
}

internal final class PlatformOptimizeSuppressionVisitor: SyntaxVisitor {
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

    override func visit(_ node: AttributeSyntax) -> SyntaxVisitorContinueKind {
        let name = node.attributeName.trimmedDescription
        if name == "_optimize" {
            if let arguments = node.arguments {
                let mode = arguments.trimmedDescription
                if mode == "none" || mode == "size" {
                    emit(at: node)
                }
            }
        } else if name == "_semantics" {
            if let value = platformOptimizeSuppressionSemanticsString(node),
                value.hasPrefix("optimize.no.")
            {
                emit(at: node)
            }
        }
        return .visitChildren
    }

    private func emit(at node: AttributeSyntax) {
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "optimize suppression attribute",
                message: platformOptimizeSuppressionMessage
            )
        )
    }
}
