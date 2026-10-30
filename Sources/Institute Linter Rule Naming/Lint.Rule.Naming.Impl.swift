public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `variable named impl` = Lint.Rule(
        id: "variable named impl",
        default: .warning,
        controls: [
            .init(
                id: "variable named impl binding",
                source: "let impl = make()",
                path: "Sources/Naming Core/ImplBinding.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "variable named impl long name",
                source: "let implementation = make()",
                path: "Sources/Naming Core/ImplementationBinding.swift",
                expectation: .clean
            ),
            .init(
                id: "variable named impl parameter",
                source: "func use(impl: Int) -> Int { impl }",
                path: "Sources/Naming Core/ImplParameter.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = NamingImplVisitor(
                source: source.file,
                severity: severity,
                converter: source.converter
            )
            visitor.walk(source.tree)
            return visitor.matches
        }
    )
}

private let namingImplMessage: Swift::String =
    "[variable named impl] [API-NAME-012]: do not bind a local as `impl` "
    + "or `_impl` — it hides the type's identity. Use the type's own name lowercased "
    + "(e.g., `let actor = IO.Blocking.Actor(...)`, `let resolver = Manifest.Resolver(...)`) "
    + "so each read site reveals what the binding actually holds."

internal final class NamingImplVisitor: SyntaxVisitor {
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

    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else {
                continue
            }
            let name = pattern.identifier.text
            guard name == "impl" || name == "_impl" else {
                continue
            }
            let location = converter.location(
                for: pattern.identifier.positionAfterSkippingLeadingTrivia
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
                    identifier: "variable named impl",
                    message: namingImplMessage
                )
            )
        }
        return .visitChildren
    }
}
