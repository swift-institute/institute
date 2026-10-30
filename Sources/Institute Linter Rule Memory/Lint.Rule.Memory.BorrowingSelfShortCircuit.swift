public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `borrowing self short circuit` = Lint.Rule(
        id: "borrowing self short circuit",
        default: .warning,
        controls: [
            .init(
                id: "borrowing self short circuit disjunction",
                source: "public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool { lhs.priority < rhs.priority || lhs.sequence < rhs.sequence }",
                path: "Sources/Memory Core/BorrowingSelfDisjunction.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "borrowing self short circuit tuple comparison",
                source: "public static func < (lhs: borrowing Self, rhs: borrowing Self) -> Bool { (lhs.priority, lhs.sequence) < (rhs.priority, rhs.sequence) }",
                path: "Sources/Memory Core/BorrowingSelfTuple.swift",
                expectation: .clean
            ),
            .init(
                id: "borrowing self short circuit nonborrowing parameters",
                source: "public static func < (lhs: Self, rhs: Self) -> Bool { lhs.priority < rhs.priority || lhs.sequence < rhs.sequence }",
                path: "Sources/Memory Core/NonborrowingDisjunction.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = MemoryBorrowingSelfShortCircuitVisitor(
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
internal let memoryBorrowingSelfShortCircuitMessage: Swift::String =
    "[borrowing self short circuit] [IMPL-094]: operator overload "
    + "with `borrowing Self` parameters uses `&&` / `||` in its body — "
    + "Swift 6.3 rejects chained property access across the short-"
    + "circuit boundary as `borrowed value escapes its borrow scope`. "
    + "Use tuple comparison `(lhs.a, lhs.b) < (rhs.a, rhs.b)` or local "
    + "`let` bindings materialising the values before the short-"
    + "circuit."

internal func memoryBorrowingSelfShortCircuitIsBorrowingSelf(
    _ parameter: FunctionParameterSyntax
) -> Swift::Bool {
    var current = parameter.type
    guard let attributed = current.as(AttributedTypeSyntax.self) else {
        return false
    }
    var hasBorrowing = false
    for specifier in attributed.specifiers {
        if let simple = specifier.as(SimpleTypeSpecifierSyntax.self) {
            if case .keyword(.borrowing) = simple.specifier.tokenKind {
                hasBorrowing = true
                break
            }
        }
    }
    guard hasBorrowing else { return false }
    current = attributed.baseType
    if let identifier = current.as(IdentifierTypeSyntax.self),
        identifier.name.tokenKind == .keyword(.Self) || identifier.name.text == "Self"
    {
        return true
    }
    return false
}

internal final class MemoryBorrowingSelfShortCircuitVisitor: SyntaxVisitor {
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

    override func visit(_ node: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.name.tokenKind == .binaryOperator(node.name.text) else {
            return .visitChildren
        }
        var borrowingSelfNames: Swift::Set<Swift::String> = []
        for parameter in node.signature.parameterClause.parameters {
            if memoryBorrowingSelfShortCircuitIsBorrowingSelf(parameter) {
                let name = parameter.secondName?.text ?? parameter.firstName.text
                borrowingSelfNames.insert(name)
            }
        }
        guard !borrowingSelfNames.isEmpty else { return .visitChildren }
        guard let body = node.body else { return .visitChildren }
        let finder = MemoryBorrowingSelfShortCircuitFinder(
            viewMode: .sourceAccurate,
            borrowingSelfNames: borrowingSelfNames
        )
        finder.walk(body)
        for position in finder.positions {
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
                    identifier: "borrowing self short circuit",
                    message: memoryBorrowingSelfShortCircuitMessage
                )
            )
        }
        return .visitChildren
    }
}
