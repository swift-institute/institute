package import Lint
internal import Linter_Rule_Scope
internal import SwiftSyntax

extension Lint.Feature {

    package static let targetSuffix: Swift::String = " Feature"

    package static let scope: Swift::String =
        "inside `@Feature` types, extensions of them, and every file of a target whose name ends "
        + "in ` Feature`"

    package static func observe(
        _ kind: Kind,
        identifier: Swift::String,
        message: Swift::String
    ) -> @Sendable (borrowing Lint.Source.Parsed, Diagnostic.Severity) -> Lint.Rule.Observation {
        Lint.Rule.measured { source, severity in
            let visitor = Visitor(
                index: Lint.Scope.Index.of(source),
                target: Lint.Scope.Target.named(source.path, suffix: targetSuffix)
            )
            visitor.walk(source.tree)
            return visitor.hits.filter { $0.kind == kind }.map { hit in
                Lint.Scope.record(
                    at: hit.node,
                    in: source,
                    severity: severity,
                    identifier: identifier,
                    message: "[\(identifier)]: \(hit.detail). \(message)"
                )
            }
        }
    }
}
