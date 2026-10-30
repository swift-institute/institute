public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `noncopyable error` = Lint.Rule(
        id: "noncopyable error",
        default: .warning,
        controls: [
            .init(
                id: "noncopyable error conformance",
                source: "struct Failure: Error, ~Copyable {}",
                path: "Sources/Memory Core/NoncopyableError.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "noncopyable error copyable",
                source: "struct Failure: Error {}",
                path: "Sources/Memory Core/CopyableError.swift",
                expectation: .clean
            ),
            .init(
                id: "noncopyable error nonerror",
                source: "struct Token: ~Copyable {}",
                path: "Sources/Memory Core/NoncopyableToken.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let collector = MemoryErrorNoncopyableExtensionCollector(viewMode: .sourceAccurate)
            collector.walk(source.tree)
            let visitor = MemoryErrorNoncopyableVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter,
                extensionConformances: collector.conformances
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

@usableFromInline
internal let memoryErrorNoncopyableMessage: Swift::String =
    "[noncopyable error] [MEM-COPY-002]: `Error`-conforming types MUST NOT "
    + "suppress `Copyable`. `Swift.Error`'s existential boxing requires `Copyable`. "
    + "A `~Copyable` Error type fails to compile or to interoperate with the "
    + "throwing protocol surface. Use a non-throwing `Outcome` enum (`.success`/"
    + "`.failure`) carrying the move-only value, or hold the move-only state in "
    + "a copyable handle and reference it from the error."

internal final class MemoryErrorNoncopyableExtensionCollector: SyntaxVisitor {
    var conformances: [Swift::String: Swift::Set<Swift::String>] = [:]

    override func visit(_ node: ExtensionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard let clause = node.inheritanceClause else { return .visitChildren }
        let key = node.extendedType.trimmedDescription
        var leaves = conformances[key] ?? []
        for inherited in clause.inheritedTypes {
            var current = inherited.type
            while let attributed = current.as(AttributedTypeSyntax.self) {
                current = attributed.baseType
            }
            if let identifier = current.as(IdentifierTypeSyntax.self) {
                leaves.insert(identifier.name.text)
            }
            if let member = current.as(MemberTypeSyntax.self) {
                leaves.insert(member.name.text)
            }
        }
        conformances[key] = leaves
        return .visitChildren
    }
}
