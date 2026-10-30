public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `tagged unchecked with typed alternative` = Lint.Rule(
        id: "tagged unchecked with typed alternative",
        default: .warning,
        controls: [
            .init(
                id: "tagged unchecked with typed alternative unchecked construction",
                source: "let value = Tagged<Tag, Int>(_unchecked: 42)",
                path: "Sources/Raw Value Core/UncheckedConstruction.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "tagged unchecked with typed alternative literal construction",
                source: "let value: Tagged<Tag, Int> = 42",
                path: "Sources/Raw Value Core/LiteralConstruction.swift",
                expectation: .clean
            ),
            .init(
                id: "tagged unchecked with typed alternative test boundary",
                source: "@Test func construction() { _ = Tagged<Tag, Int>(_unchecked: 42) }",
                path: "Tests/Raw Value Tests/UncheckedConstruction.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = RawValueTaggedUncheckedVisitor(
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
internal let rawValueTaggedUncheckedMessage: Swift::String =
    "[tagged unchecked with typed alternative] [CONV-015]: "
    + "`Tagged<…>(_unchecked: …)` bypasses tagged' typed-init alternatives "
    + "(ExpressibleBy*Literal conformances in the Standard Library Integration target). "
    + "Prefer a literal-typed init when the underlying type's literal protocol fits; "
    + "reach for `_unchecked` only when the underlying value is already validated upstream "
    + "and a typed init is genuinely unavailable."

@usableFromInline
internal let rawValueTaggedUncheckedExemptOperations: [Swift::String: Swift::String] = [
    "map": "preserve-shape transform; closure output is opaque-by-construction",
    "retag": "phantom-tag swap; underlying validated upstream by Tagged construction invariant",
]

@usableFromInline
internal let rawValueTaggedUncheckedExemptAttributes: [Swift::String: Swift::String] = [
    "Test": "swift-testing test function; tests exercise the full API surface including _unchecked"
]

internal final class RawValueTaggedUncheckedVisitor: SyntaxVisitor {
    let source: Source.File
    let severity: Diagnostic.Severity
    let converter: SourceLocationConverter
    var matches: [Diagnostic.Record] = []

    init(
        source: Source.File,
        severity: Diagnostic.Severity,
        converter: SourceLocationConverter
    ) {
        self.source = source
        self.severity = severity
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard Self.calleeIsTagged(node.calledExpression) else {
            return .visitChildren
        }
        if Self.isInsideExemptOperation(Syntax(node)) {
            return .visitChildren
        }
        for argument in node.arguments {
            guard
                let label = argument.label,
                label.tokenKind == .identifier("_unchecked")
            else { continue }
            let location = converter.location(
                for: argument.positionAfterSkippingLeadingTrivia
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
                    identifier: "tagged unchecked with typed alternative",
                    message: rawValueTaggedUncheckedMessage
                )
            )
            break
        }
        return .visitChildren
    }

    private static func isInsideExemptOperation(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if let fn = candidate.as(FunctionDeclSyntax.self) {
                if rawValueTaggedUncheckedExemptOperations[fn.name.text] != nil {
                    return true
                }
                if Self.hasExemptAttribute(fn.attributes) {
                    return true
                }
                return false
            }
            current = candidate.parent
        }
        return false
    }

    private static func hasExemptAttribute(_ attributes: AttributeListSyntax) -> Swift::Bool {
        for element in attributes {
            guard case .attribute(let attribute) = element else { continue }
            let name: Swift::String
            if let ident = attribute.attributeName.as(IdentifierTypeSyntax.self) {
                name = ident.name.text
            } else if let member = attribute.attributeName.as(MemberTypeSyntax.self) {
                name = member.name.text
            } else {
                continue
            }
            if rawValueTaggedUncheckedExemptAttributes[name] != nil {
                return true
            }
        }
        return false
    }

    private static func calleeIsTagged(_ expression: ExprSyntax) -> Bool {
        if let decl = expression.as(DeclReferenceExprSyntax.self) {
            return decl.baseName.text == "Tagged"
        }
        if let generic = expression.as(GenericSpecializationExprSyntax.self) {
            return calleeIsTagged(generic.expression)
        }
        if let member = expression.as(MemberAccessExprSyntax.self) {
            if member.declName.baseName.text == "Tagged" {
                return true
            }
            if member.declName.baseName.text == "init", let base = member.base {
                return calleeIsTagged(base)
            }
        }
        return false
    }
}
