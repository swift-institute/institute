public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `unchecked try outside tests` = Lint.Rule(
        id: "unchecked try outside tests",
        default: .warning,
        controls: [
            .init(
                id: "unchecked try outside tests source",
                source: "let value = try! load()",
                path: "Sources/Try Consumer/ForcedTry.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unchecked try outside tests propagating",
                source: "let value = try load()",
                path: "Sources/Try Consumer/PropagatingTry.swift",
                expectation: .clean
            ),
            .init(
                id: "unchecked try outside tests test",
                source: "let value = try! load()",
                path: "Tests/Try Consumer Tests/ForcedTry.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return []
            }
            let visitor = TryUncheckedOutsideTestsVisitor(
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
internal let tryUncheckedOutsideTestsMessage: Swift::String =
    "[unchecked try outside tests] [SOURCE-UNCHECKED-TRY]: `try!` traps on any "
    + "thrown error; library and executable sources propagate the typed error "
    + "instead. `try!` is admitted only in tests and fixtures."

internal final class TryUncheckedOutsideTestsVisitor: SyntaxVisitor {
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

    override func visit(_ node: TryExprSyntax) -> SyntaxVisitorContinueKind {
        guard let mark = node.questionOrExclamationMark,
            mark.tokenKind == .exclamationMark
        else {
            return .visitChildren
        }
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
                identifier: "unchecked try outside tests",
                message: tryUncheckedOutsideTestsMessage
            )
        )
        return .visitChildren
    }
}
