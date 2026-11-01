public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    /// Code that waits takes a clock, so a test runs it on a test clock and never actually sleeps (#246).
    public static let `task sleep` = Lint.Rule(
        id: "task sleep",
        default: .warning,
        controls: [
            .init(
                id: "task sleep in sources",
                source: "func poll() async throws { try await Task.sleep(for: .seconds(2)) }",
                path: "Sources/Idiom Consumer/Poll.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "task sleep thread sleep in sources",
                source: "func wait() { Thread.sleep(forTimeInterval: 1) }",
                path: "Sources/Idiom Consumer/Wait.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "task sleep on an injected clock",
                source: "func poll<C: Clock<Duration>>(clock: C) async throws { try await clock.sleep(for: .seconds(2)) }",
                path: "Sources/Idiom Consumer/Poll.swift",
                expectation: .clean
            ),
            .init(
                id: "task sleep in tests",
                source: "func poll() async throws { try await Task.sleep(for: .seconds(2)) }",
                path: "Tests/Idiom Consumer Tests/Poll.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let path = source.file.filePath
            guard path.hasPrefix("Sources/") || path.contains("/Sources/") else {
                return []
            }
            let visitor = IdiomTaskSleepVisitor(source: source.file, severity: severity, converter: source.converter)
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

internal let idiomTaskSleepMessage: Swift::String =
    "[task sleep]: `Task.sleep` and `Thread.sleep` wait on the wall clock, so a test of this code waits too. Take a "
    + "`Clock` (a parameter or a dependency) and sleep on it; a test passes a test clock and never sleeps."

internal final class IdiomTaskSleepVisitor: SyntaxVisitor {
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
        guard let member = node.calledExpression.as(MemberAccessExprSyntax.self),
            member.declName.baseName.text == "sleep",
            let base = member.base?.as(DeclReferenceExprSyntax.self)?.baseName.text,
            base == "Task" || base == "Thread"
        else { return .visitChildren }
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(fileID: source.fileID, filePath: source.filePath, line: location.line, column: location.column),
                severity: severity,
                identifier: "task sleep",
                message: idiomTaskSleepMessage
            )
        )
        return .visitChildren
    }
}
