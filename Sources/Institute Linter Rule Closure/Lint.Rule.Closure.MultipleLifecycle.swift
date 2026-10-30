public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `unlabeled lifecycle closure` = Lint.Rule(
        id: "unlabeled lifecycle closure",
        default: .warning,
        controls: [
            .init(
                id: "unlabeled lifecycle closure secondary",
                source: "func perform(_ body: () -> Void, _ completion: () -> Void) {}",
                path: "Sources/Closure Core/UnlabeledSecondary.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "unlabeled lifecycle closure labelled secondary",
                source: "func perform(_ body: () -> Void, completion: () -> Void) {}",
                path: "Sources/Closure Core/LabelledSecondary.swift",
                expectation: .clean
            ),
            .init(
                id: "unlabeled lifecycle closure single",
                source: "func perform(_ body: () -> Void) {}",
                path: "Sources/Closure Core/SingleClosure.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ClosureMultipleLifecycleVisitor(
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
internal let closureMultipleLifecycleMessage: Swift::String =
    "[unlabeled lifecycle closure] [API-IMPL-013]: signatures with two or more closure "
    + "parameters MUST label every closure after the primary body closure. The "
    + "secondary closure label names the closure's *role* (`completion:`, "
    + "`onError:`, `progress:`) — not its type. Per [API-NAME-002], roles over "
    + "types. Lifecycle order is setup → body → completion / teardown."

internal final class ClosureMultipleLifecycleVisitor: SyntaxVisitor {
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
                identifier: "unlabeled lifecycle closure",
                message: closureMultipleLifecycleMessage
            )
        )
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        var closureCount = 0
        for parameter in parameters {
            guard isClosureType(parameter.type) else { continue }
            closureCount += 1
            if closureCount >= 2, parameter.firstName.tokenKind == .wildcard {
                emit(at: parameter.firstName.positionAfterSkippingLeadingTrivia)
            }
        }
    }

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        checkParameters(node.signature.parameterClause.parameters)
        return .visitChildren
    }
}
