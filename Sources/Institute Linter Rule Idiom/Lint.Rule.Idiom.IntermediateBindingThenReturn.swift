public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `intermediate binding then return` = Lint.Rule(
        id: "intermediate binding then return",
        default: .warning,
        controls: [
            .init(
                id: "intermediate binding then return redundant",
                source: "func value() -> Int { let result = compute(); return result }",
                path: "Sources/Idiom Core/IntermediateReturn.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "intermediate binding then return annotated",
                source: "func value() -> Int { let result: Int = compute(); return result }",
                path: "Sources/Idiom Core/AnnotatedReturn.swift",
                expectation: .clean
            ),
            .init(
                id: "intermediate binding then return direct",
                source: "func value() -> Int { return compute() }",
                path: "Sources/Idiom Core/DirectReturn.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = IdiomIntermediateBindingThenReturnVisitor(
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
internal let idiomIntermediateBindingThenReturnMessage: Swift::String =
    "[intermediate binding then return] [IMPL-EXPR-001]: `let <name> = "
    + "<expr>; return <name>` adds mechanism. Return the expression "
    + "directly: `return <expr>`. The binding is justified only when the "
    + "name communicates domain knowledge the expression doesn't, or when "
    + "the value is consumed more than once — neither applies here. "
    + "(An explicitly-typed binding, `let <name>: T = <expr>`, is exempt "
    + "— the annotation itself is a domain/intent signal.)"

internal final class IdiomIntermediateBindingThenReturnVisitor: SyntaxVisitor {
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

    override func visit(_ node: CodeBlockItemListSyntax) -> SyntaxVisitorContinueKind {
        let items = Array(node)
        for i in items.indices.dropLast() {
            let first = items[i]
            let second = items[items.index(after: i)]
            guard let varDecl = first.item.as(VariableDeclSyntax.self) else { continue }
            guard case .keyword(.let) = varDecl.bindingSpecifier.tokenKind else { continue }
            guard varDecl.bindings.count == 1,
                let binding = varDecl.bindings.first,
                let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                binding.typeAnnotation == nil,
                binding.initializer != nil
            else { continue }
            guard let returnStmt = second.item.as(ReturnStmtSyntax.self) else { continue }
            guard let expression = returnStmt.expression else { continue }
            guard let reference = expression.as(DeclReferenceExprSyntax.self) else { continue }
            guard reference.baseName.text == pattern.identifier.text else { continue }
            let location = converter.location(
                for: varDecl.bindingSpecifier.positionAfterSkippingLeadingTrivia
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
                    identifier: "intermediate binding then return",
                    message: idiomIntermediateBindingThenReturnMessage
                )
            )
        }
        return .visitChildren
    }
}
