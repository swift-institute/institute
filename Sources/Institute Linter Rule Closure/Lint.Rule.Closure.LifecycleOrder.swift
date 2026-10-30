public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `lifecycle order` = Lint.Rule(
        id: "lifecycle order",
        default: .warning,
        controls: [
            .init(
                id: "lifecycle order completion before body",
                source: "func perform(completion: () -> Void, body: () -> Void) {}",
                path: "Sources/Closure Core/CompletionBeforeBody.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "lifecycle order canonical",
                source: "func perform(setup: () -> Void, body: () -> Void, completion: () -> Void) {}",
                path: "Sources/Closure Core/CanonicalLifecycle.swift",
                expectation: .clean
            ),
            .init(
                id: "lifecycle order other labels",
                source: "func perform(first: () -> Void, second: () -> Void) {}",
                path: "Sources/Closure Core/OtherClosures.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ClosureLifecycleOrderVisitor(
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
internal let closureLifecycleOrderMessage: Swift::String =
    "[lifecycle order] [API-IMPL-013]: closure parameters "
    + "MUST follow lifecycle order setup → body → completion / teardown. "
    + "A closure parameter of a later tier (a setup-tier label like "
    + "`setup:`/`prepare:`; a body-tier label like `body:`/`perform:` or "
    + "the unlabelled `_`; a completion-tier label like `completion:`, "
    + "`onError:`, `cleanup:`, `teardown:`, `finalize:`) appears BEFORE a "
    + "parameter of an earlier tier — reorder so setup precedes body "
    + "precedes completion."

internal let setupTierLabels: Swift::Set<Swift::String> = [
    "setup",
    "prepare",
    "onStart",
    "before",
    "configure",
    "arrange",
]

internal let completionTierLabels: Swift::Set<Swift::String> = [
    "completion",
    "onError",
    "onComplete",
    "onCompletion",
    "onFinish",
    "finalize",
    "finally",
    "cleanup",
    "teardown",
    "close",
    "dispose",
]

internal let bodyTierLabels: Swift::Set<Swift::String> = [
    "body",
    "perform",
    "operation",
    "work",
    "action",
    "transform",
]

internal final class ClosureLifecycleOrderVisitor: SyntaxVisitor {
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
                identifier: "lifecycle order",
                message: closureLifecycleOrderMessage
            )
        )
    }

    private func checkParameters(_ parameters: FunctionParameterListSyntax) {
        var pending: [Tier: [AbsolutePosition]] = [:]
        for parameter in parameters {
            guard isClosureType(parameter.type) else { continue }
            let current = tier(of: parameter)
            guard current != .other else { continue }

            for laterTier in Tier.allCases
            where laterTier != .other && laterTier.rank > current.rank {
                guard let positions = pending[laterTier], !positions.isEmpty else { continue }
                for position in positions {
                    emit(at: position)
                }
                pending[laterTier] = []
            }
            pending[current, default: []].append(
                parameter.firstName.positionAfterSkippingLeadingTrivia
            )
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
