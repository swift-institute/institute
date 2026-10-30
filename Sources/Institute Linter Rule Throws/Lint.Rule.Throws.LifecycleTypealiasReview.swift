public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `lifecycle typealias review` = Lint.Rule(
        id: "lifecycle typealias review",
        default: .note,
        controls: [
            .init(
                id: "lifecycle typealias review shared lifecycle error",
                source: "typealias Error = Async.Lifecycle.Error",
                path: "Sources/Throws Consumer/SharedLifecycleError.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "lifecycle typealias review domain error",
                source: "typealias Error = Async.Parse.Error",
                path: "Sources/Throws Consumer/DomainError.swift",
                expectation: .clean
            ),
            .init(
                id: "lifecycle typealias review nonerror alias",
                source: "typealias Failure = Async.Lifecycle.Error",
                path: "Sources/Throws Consumer/FailureAlias.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = ThrowsLifecycleTypealiasReviewVisitor(
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
internal let throwsLifecycleTypealiasReviewMessage: Swift::String =
    "[lifecycle typealias review] [API-ERR-008]: typealias `Error = "
    + "<Domain>.Lifecycle.Error` adopts a SHARED lifecycle-error type. "
    + "Confirm the primitive actually produces EVERY case of the "
    + "lifecycle type."

private func lifecycleIsLifecycleErrorMemberType(_ type: TypeSyntax) -> Swift::Bool {
    guard let member = type.as(MemberTypeSyntax.self) else { return false }
    guard member.name.text == "Error" else { return false }
    guard let parent = member.baseType.as(MemberTypeSyntax.self) else {
        if let base = member.baseType.as(IdentifierTypeSyntax.self),
            base.name.text == "Lifecycle"
        {
            return true
        }
        return false
    }
    return parent.name.text == "Lifecycle"
}

internal final class ThrowsLifecycleTypealiasReviewVisitor: SyntaxVisitor {
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

    override func visit(_ node: TypeAliasDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.name.text == "Error" else { return .visitChildren }
        let initialized = node.initializer.value
        guard lifecycleIsLifecycleErrorMemberType(initialized) else { return .visitChildren }
        let location = converter.location(for: node.name.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "lifecycle typealias review",
                message: throwsLifecycleTypealiasReviewMessage
            )
        )
        return .visitChildren
    }
}
