public import Lint
internal import SwiftSyntax

extension Lint.Rule {
    public static let `throwing wrapper init` = Lint.Rule(
        id: "throwing wrapper init",
        default: .warning,
        controls: [
            .init(
                id: "throwing wrapper init base forward",
                source: "struct Wrapper { init(_ raw: Int) throws { self.base = try Base(raw) } }",
                path: "Sources/Structure Core/Wrapper.swift",
                expectation: .findings(1)
            ),
            .init(
                id: "throwing wrapper init validates invariant",
                source: "struct Wrapper { init(_ raw: Int) throws { "
                    + "self.base = try Base(raw); try validate(base) } }",
                path: "Sources/Structure Core/Wrapper.swift",
                expectation: .clean
            ),
            .init(
                id: "throwing wrapper init lax primitive",
                source: "extension Int { init(_ value: Wrapper) throws { "
                    + "self = try UInt(value) } }",
                path: "Sources/Structure Core/Int.swift",
                expectation: .clean
            ),
        ],
        observe: Lint.Rule.measured { source, severity in
            let visitor = StructureThrowingWrapperInitVisitor(
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
internal let structureThrowingWrapperInitMessage: Swift::String =
    "[throwing wrapper init] [PATTERN-020]: throwing init body "
    + "is a single `try base.init(...)` forward with no additional validation. "
    + "If the wrapper specializes to a stricter invariant than its base, the "
    + "wrapper's invariant is silently violable. Add the wrapper's validation "
    + "after the base-init call, or rewrite the init to validate the wrapper "
    + "invariant directly."

@usableFromInline
internal let structureThrowingWrapperInitLaxTypeAllowlist: Swift::Set<Swift::String> = [
    "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Float", "Float16", "Float32", "Float64", "Float80", "Double",
    "Bool",
    "String", "Substring", "Character",
]

internal final class StructureThrowingWrapperInitVisitor: SyntaxVisitor {
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

    override func visit(_ node: InitializerDeclSyntax) -> SyntaxVisitorContinueKind {
        guard node.signature.effectSpecifiers?.throwsClause != nil else {
            return .visitChildren
        }
        guard let body = node.body else { return .visitChildren }
        let statements = body.statements
        guard statements.count == 1 else { return .visitChildren }
        guard let only = statements.first?.item else { return .visitChildren }
        guard isBaseInitializerTryForward(Syntax(only)) else { return .visitChildren }
        if isInsideExtensionOnLaxType(Syntax(node)) {
            return .visitChildren
        }
        let location = converter.location(
            for: node.initKeyword.positionAfterSkippingLeadingTrivia
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
                identifier: "throwing wrapper init",
                message: structureThrowingWrapperInitMessage
            )
        )
        return .visitChildren
    }

    private func isInsideExtensionOnLaxType(_ node: Syntax) -> Swift::Bool {
        var current: Syntax? = node.parent
        while let candidate = current {
            if let ext = candidate.as(ExtensionDeclSyntax.self) {
                if let identifier = ext.extendedType.as(IdentifierTypeSyntax.self) {
                    return structureThrowingWrapperInitLaxTypeAllowlist.contains(
                        identifier.name.text
                    )
                }
                if let member = ext.extendedType.as(MemberTypeSyntax.self) {
                    return structureThrowingWrapperInitLaxTypeAllowlist.contains(member.name.text)
                }
                return false
            }
            if candidate.is(StructDeclSyntax.self)
                || candidate.is(ClassDeclSyntax.self)
                || candidate.is(EnumDeclSyntax.self)
                || candidate.is(ActorDeclSyntax.self)
                || candidate.is(ProtocolDeclSyntax.self)
            {
                return false
            }
            current = candidate.parent
        }
        return false
    }

    private func extractTryExpr(_ syntax: Syntax) -> TryExprSyntax? {
        if let tryExpr = syntax.as(TryExprSyntax.self) {
            return tryExpr
        }
        if let variableDecl = syntax.as(VariableDeclSyntax.self),
            variableDecl.bindings.count == 1,
            let binding = variableDecl.bindings.first,
            let initializer = binding.initializer,
            let tryExpr = initializer.value.as(TryExprSyntax.self)
        {
            return tryExpr
        }
        if let sequence = syntax.as(SequenceExprSyntax.self) {
            for element in sequence.elements {
                if let tryExpr = element.as(TryExprSyntax.self) {
                    return tryExpr
                }
            }
        }
        return nil
    }

    private func isBaseInitializerTryForward(_ syntax: Syntax) -> Swift::Bool {
        if let sequence = syntax.as(SequenceExprSyntax.self) {
            let elements = Array(sequence.elements)
            if elements.count == 3, elements[1].is(AssignmentExprSyntax.self) {
                let sawTry =
                    elements[0].is(TryExprSyntax.self) || elements[2].is(TryExprSyntax.self)
                guard sawTry else { return false }
                let rhs = elements[2].as(TryExprSyntax.self)?.expression ?? elements[2]
                return isConstructorCall(rhs)
            }
        }
        guard let tryExpr = extractTryExpr(syntax) else { return false }
        let inner = tryExpr.expression
        if let infix = inner.as(InfixOperatorExprSyntax.self),
            infix.operator.is(AssignmentExprSyntax.self)
        {
            return isConstructorCall(infix.rightOperand)
        }
        return isConstructorCall(inner)
    }

    private func isConstructorCall(_ expr: ExprSyntax) -> Swift::Bool {
        var current = expr
        if let tuple = current.as(TupleExprSyntax.self),
            tuple.elements.count == 1,
            let only = tuple.elements.first?.expression,
            tuple.elements.first?.label == nil
        {
            current = only
        }
        guard let call = current.as(FunctionCallExprSyntax.self) else { return false }
        return calleeIsConstructor(call.calledExpression)
    }

    private func calleeIsConstructor(_ expr: ExprSyntax) -> Swift::Bool {
        if let generic = expr.as(GenericSpecializationExprSyntax.self) {
            return calleeIsConstructor(generic.expression)
        }
        if let member = expr.as(MemberAccessExprSyntax.self) {
            return member.declName.baseName.text == "init"
        }
        if let decl = expr.as(DeclReferenceExprSyntax.self) {
            guard let first = decl.baseName.text.first else { return false }
            return first.isUppercase
        }
        return false
    }
}
