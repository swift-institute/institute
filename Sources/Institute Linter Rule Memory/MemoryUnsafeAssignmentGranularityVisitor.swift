internal import Lint
internal import SwiftSyntax

internal final class MemoryUnsafeAssignmentGranularityVisitor: SyntaxVisitor {
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

    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        let elements = Array(node.elements)
        for index in elements.indices.dropLast() where index > elements.indices.startIndex {
            guard elements[index].is(AssignmentExprSyntax.self) else { continue }
            let lhs = elements[index - 1]
            guard !lhs.is(UnsafeExprSyntax.self) else { continue }
            guard memoryUnsafeAssignmentGranularityLHSIsUnsafeDestination(lhs) else { continue }
            let rhs = elements[index + 1]
            guard rhs.is(UnsafeExprSyntax.self) else { continue }
            let location = converter.location(
                for: rhs.positionAfterSkippingLeadingTrivia
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
                    identifier: "unsafe assignment granularity",
                    message: memoryUnsafeAssignmentGranularityMessage
                )
            )
        }
        return .visitChildren
    }
}
