public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    /// A manifest reads as a declaration: its package is written out, never computed.
    ///
    /// SwiftPM's declarative manifest parser (swiftlang/swift-package-manager#9933) reads `Package.swift` without
    /// running it, and the Institute's manifest rules read it the same way. Both take literal `Package(...)` arguments,
    /// `let` constants, `package.<property>.append(...)` or `+=` at top level and `#if`; a closure, a `var`, a loop or
    /// other control flow makes the manifest a program they cannot read. The canonical settings tail is the one loop
    /// the Institute sanctions (#249).
    public static let `declarative manifest` = Lint.Rule(
        id: "declarative manifest",
        default: .warning,
        controls: [
            .init(
                id: "declarative manifest literal",
                source: "let package = Package(name: \"Fixture\", products: [.library(name: \"A\", targets: [\"A\"])])\n\n"
                    + manifestCanonicalSettingsTail,
                path: "Package.swift",
                expectation: .clean
            ),
            .init(
                id: "declarative manifest mapped products",
                source: "let package = Package(name: \"Fixture\")\n"
                    + "package.products += [\"A\"].map { .library(name: $0, targets: [$0]) }\n",
                path: "Package.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "declarative manifest loop",
                source: "let package = Package(name: \"Fixture\")\nfor target in extra {\n    target.swiftSettings = []\n}\n",
                path: "Package.swift",
                expectation: .findings(1)
            ),
        ],
        observe: { source, severity in
            guard manifestIsPackageManifest(source.file.filePath, path: source.path.underlying, text: source.tree.description) else {
                return Lint.Rule.Observation(findings: [], coverage: .measured, applicability: .inapplicable)
            }
            let visitor = ManifestDeclarativeVisitor(source: source.file, severity: severity, converter: source.converter)
            visitor.inspect(source.tree.statements)
            return Lint.Rule.Observation(findings: visitor.matches, coverage: .measured)
        }
    )
}

internal final class ManifestDeclarativeVisitor: SyntaxVisitor {
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

    /// Judges each top-level statement, and walks what it may hold for closures.
    func inspect(_ statements: CodeBlockItemListSyntax) {
        for statement in statements {
            let item = statement.item
            if item.is(ImportDeclSyntax.self) { continue }
            if let declaration = item.as(VariableDeclSyntax.self) {
                guard declaration.bindingSpecifier.tokenKind == .keyword(.let) else {
                    record(Syntax(declaration), "a `var`")
                    continue
                }
                walk(declaration)
                continue
            }
            if let conditional = item.as(IfConfigDeclSyntax.self) {
                for clause in conditional.clauses {
                    if case .statements(let nested) = clause.elements { inspect(nested) }
                }
                continue
            }
            if let loop = item.as(ForStmtSyntax.self), manifestDeclarativeIsSettingsTail(loop) { continue }
            if let expression = item.as(ExprSyntax.self), manifestDeclarativeIsPackageAppend(expression) {
                walk(expression)
                continue
            }
            record(Syntax(item), manifestDeclarativeKind(item))
        }
    }

    override func visit(_ node: ClosureExprSyntax) -> SyntaxVisitorContinueKind {
        record(Syntax(node), "a closure")
        return .skipChildren
    }

    private func record(_ node: Syntax, _ construct: Swift::String) {
        let location = converter.location(for: node.positionAfterSkippingLeadingTrivia)
        matches.append(
            Diagnostic.Record(
                location: Source.Location(
                    fileID: source.fileID,
                    filePath: source.filePath,
                    line: location.line,
                    column: location.column
                ),
                severity: severity,
                identifier: "declarative manifest",
                message: "[declarative manifest]: \(construct) makes Package.swift a program, which neither SwiftPM's "
                    + "declarative manifest parser nor the Institute's manifest rules can read. Write the package out: "
                    + "literal Package(...) arguments, `let` constants, package.<property>.append(...) or += at top "
                    + "level, and #if; one .library per product instead of a map over names. The canonical settings "
                    + "tail is the one sanctioned loop (swift-institute/institute#249)."
            )
        )
    }
}

/// Whether `loop` is the canonical settings tail's `for target in package.targets`.
private func manifestDeclarativeIsSettingsTail(_ loop: ForStmtSyntax) -> Swift::Bool {
    guard let sequence = loop.sequence.as(MemberAccessExprSyntax.self),
        let base = sequence.base?.as(DeclReferenceExprSyntax.self)
    else { return false }
    return base.baseName.text == "package" && sequence.declName.baseName.text == "targets"
}

/// Whether `expression` is `package.<property>.append(...)` or `package.<property> += ...`.
private func manifestDeclarativeIsPackageAppend(_ expression: ExprSyntax) -> Swift::Bool {
    if let call = expression.as(FunctionCallExprSyntax.self),
        let member = call.calledExpression.as(MemberAccessExprSyntax.self),
        member.declName.baseName.text == "append"
    {
        return manifestDeclarativeIsPackageProperty(member.base)
    }
    if let infix = expression.as(InfixOperatorExprSyntax.self),
        let operation = infix.operator.as(BinaryOperatorExprSyntax.self),
        operation.operator.text == "+="
    {
        return manifestDeclarativeIsPackageProperty(infix.leftOperand)
    }
    // An unfolded tree spells `package.products += [...]` as a sequence: operand, operator, operand.
    if let sequence = expression.as(SequenceExprSyntax.self), sequence.elements.count == 3 {
        let elements = Swift::Array(sequence.elements)
        guard let operation = elements[1].as(BinaryOperatorExprSyntax.self), operation.operator.text == "+="
        else { return false }
        return manifestDeclarativeIsPackageProperty(elements[0])
    }
    return false
}

private func manifestDeclarativeIsPackageProperty(_ expression: ExprSyntax?) -> Swift::Bool {
    guard let member = expression?.as(MemberAccessExprSyntax.self),
        let base = member.base?.as(DeclReferenceExprSyntax.self)
    else { return false }
    return base.baseName.text == "package"
}

/// What a top-level statement the parser cannot read is, in words.
private func manifestDeclarativeKind(_ item: CodeBlockItemSyntax.Item) -> Swift::String {
    if item.is(ForStmtSyntax.self) || item.is(WhileStmtSyntax.self) || item.is(RepeatStmtSyntax.self) {
        return "a loop other than the settings tail"
    }
    if item.is(FunctionDeclSyntax.self) { return "a function" }
    if item.is(DeclSyntax.self) { return "a declaration other than `let`" }
    return "top-level control flow or a computed statement"
}
