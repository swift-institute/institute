internal import Lint
internal import SwiftSyntax

internal func idiomIterationIntentFixed(
    _ source: borrowing Lint.Source.Parsed
) -> Swift::String? {
    let rewriter = IdiomIterationIntentRewriter()
    let rewritten = rewriter.visit(source.tree)
    guard rewriter.changed else { return nil }
    return rewritten.description
}

internal func idiomIterationIntentIsFixable(_ loop: ForStmtSyntax) -> Swift::Bool {
    guard loop.pattern.is(IdentifierPatternSyntax.self) else { return false }
    guard idiomIsRangeExpression(loop.sequence) else { return false }
    guard !idiomLoopPreservesTypedThrows(loop) else { return false }
    guard loop.whereClause == nil, loop.typeAnnotation == nil else { return false }
    guard loop.parent?.as(LabeledStmtSyntax.self) == nil else { return false }
    guard !idiomIterationIntentProducesContent(loop) else { return false }
    guard !idiomIterationIntentDropsComments(loop) else { return false }
    guard !idiomIterationIntentReferencesOwnershipAnnotatedBinding(loop) else { return false }
    return !idiomIterationIntentBodyEscapes(Syntax(loop.body))
}

private func idiomIterationIntentReferencesOwnershipAnnotatedBinding(
    _ loop: ForStmtSyntax
) -> Swift::Bool {
    let names = idiomEnclosingOwnershipAnnotatedParameterNames(Syntax(loop))
    guard !names.isEmpty else { return false }
    return idiomSubtreeReferencesAnyName(names, in: Syntax(loop.body))
}

private func idiomEnclosingOwnershipAnnotatedParameterNames(
    _ node: Syntax
) -> Swift::Set<Swift::String> {
    var current: Syntax? = node.parent
    while let candidate = current {
        if let function = candidate.as(FunctionDeclSyntax.self) {
            return idiomOwnershipAnnotatedParameterNames(
                function.signature.parameterClause.parameters
            )
        }
        if let initializer = candidate.as(InitializerDeclSyntax.self) {
            return idiomOwnershipAnnotatedParameterNames(
                initializer.signature.parameterClause.parameters
            )
        }
        if let subscriptDecl = candidate.as(SubscriptDeclSyntax.self) {
            return idiomOwnershipAnnotatedParameterNames(subscriptDecl.parameterClause.parameters)
        }
        current = candidate.parent
    }
    return []
}

private func idiomOwnershipAnnotatedParameterNames(
    _ parameters: FunctionParameterListSyntax
) -> Swift::Set<Swift::String> {
    var names: Swift::Set<Swift::String> = []
    for parameter in parameters {
        guard let attributed = parameter.type.as(AttributedTypeSyntax.self) else { continue }
        for specifier in attributed.specifiers {
            guard let simple = specifier.as(SimpleTypeSpecifierSyntax.self) else { continue }
            let kind = simple.specifier.tokenKind
            guard kind == .keyword(.borrowing) || kind == .keyword(.consuming) else { continue }
            names.insert((parameter.secondName ?? parameter.firstName).text)
            break
        }
    }
    return names
}

private func idiomSubtreeReferencesAnyName(
    _ names: Swift::Set<Swift::String>,
    in node: Syntax
) -> Swift::Bool {
    if node.is(ClosureExprSyntax.self) { return false }
    if node.is(FunctionDeclSyntax.self) { return false }
    if let reference = node.as(DeclReferenceExprSyntax.self) {
        return names.contains(reference.baseName.text)
    }
    for child in node.children(viewMode: .sourceAccurate) {
        if idiomSubtreeReferencesAnyName(names, in: child) { return true }
    }
    return false
}

private func idiomIterationIntentDropsComments(_ loop: ForStmtSyntax) -> Swift::Bool {
    let dropped: [Trivia] = [
        loop.forKeyword.trailingTrivia,
        loop.pattern.leadingTrivia,
        loop.pattern.trailingTrivia,
        loop.inKeyword.leadingTrivia,
        loop.inKeyword.trailingTrivia,
        loop.sequence.leadingTrivia,
        loop.sequence.trailingTrivia,
        loop.body.leftBrace.leadingTrivia,
    ]
    return dropped.contains(where: idiomTriviaHasComment)
}

private func idiomTriviaHasComment(_ trivia: Trivia) -> Swift::Bool {
    for piece in trivia {
        switch piece {
        case .spaces, .tabs, .newlines, .carriageReturns, .carriageReturnLineFeeds,
            .formfeeds, .verticalTabs:
            continue

        default:
            return true
        }
    }
    return false
}

private func idiomIterationIntentProducesContent(_ loop: ForStmtSyntax) -> Swift::Bool {
    var node: Syntax? = Syntax(loop).parent
    while let current = node {
        if current.is(ClosureExprSyntax.self) { return true }
        if let attributes = idiomDeclarationAttributes(current) {
            return idiomAttributesNameABuilder(attributes)
                || idiomDeclarationResultIsOpaque(current)
        }
        node = current.parent
    }
    return false
}

private func idiomDeclarationAttributes(_ node: Syntax) -> AttributeListSyntax? {
    if let decl = node.as(FunctionDeclSyntax.self) { return decl.attributes }
    if let decl = node.as(InitializerDeclSyntax.self) { return decl.attributes }
    if let decl = node.as(SubscriptDeclSyntax.self) { return decl.attributes }
    if let decl = node.as(VariableDeclSyntax.self) { return decl.attributes }
    if let decl = node.as(AccessorDeclSyntax.self) { return decl.attributes }
    return nil
}

private func idiomAttributesNameABuilder(_ attributes: AttributeListSyntax) -> Swift::Bool {
    for element in attributes {
        guard case .attribute(let attribute) = element else { continue }
        let name = attribute.attributeName.trimmedDescription
        let simple = name.split(separator: ".").last.map(Swift::String.init) ?? name
        if simple.hasSuffix("Builder") { return true }
    }
    return false
}

private func idiomDeclarationResultIsOpaque(_ node: Syntax) -> Swift::Bool {
    if let decl = node.as(FunctionDeclSyntax.self) {
        return idiomTypeIsOpaque(decl.signature.returnClause?.type)
    }
    if let decl = node.as(SubscriptDeclSyntax.self) {
        return idiomTypeIsOpaque(decl.returnClause.type)
    }
    if let decl = node.as(VariableDeclSyntax.self) {
        for binding in decl.bindings where idiomTypeIsOpaque(binding.typeAnnotation?.type) {
            return true
        }
        return false
    }
    if let decl = node.as(AccessorDeclSyntax.self) {
        let property = decl.parent?.parent?.parent?.as(PatternBindingSyntax.self)
        return idiomTypeIsOpaque(property?.typeAnnotation?.type)
    }
    return false
}

private func idiomTypeIsOpaque(_ type: TypeSyntax?) -> Swift::Bool {
    guard let type = type?.as(SomeOrAnyTypeSyntax.self) else { return false }
    return type.someOrAnySpecifier.tokenKind == .keyword(.some)
}

private func idiomIterationIntentBodyEscapes(_ node: Syntax) -> Swift::Bool {
    if node.is(BreakStmtSyntax.self) { return true }
    if node.is(ContinueStmtSyntax.self) { return true }
    if node.is(ReturnStmtSyntax.self) { return true }
    if node.is(ThrowStmtSyntax.self) { return true }
    if node.is(TryExprSyntax.self) { return true }
    if node.is(AwaitExprSyntax.self) { return true }
    if node.is(YieldStmtSyntax.self) { return true }
    for child in node.children(viewMode: .sourceAccurate) {
        if idiomIterationIntentBodyEscapes(child) { return true }
    }
    return false
}

internal func idiomIterationIntentCall(for loop: ForStmtSyntax) -> ExprSyntax? {
    guard let pattern = loop.pattern.as(IdentifierPatternSyntax.self) else { return nil }

    let bare = loop.sequence.with(\.leadingTrivia, []).with(\.trailingTrivia, [])
    let receiver: ExprSyntax =
        if bare.is(SequenceExprSyntax.self) || bare.is(InfixOperatorExprSyntax.self) {
            ExprSyntax(
                TupleExprSyntax(
                    elements: LabeledExprListSyntax([LabeledExprSyntax(expression: bare)])
                )
            )
        } else {
            bare
        }

    let braceTrailing = loop.body.leftBrace.trailingTrivia
    let firstLeading = loop.body.statements.first?.leadingTrivia ?? []
    let inTrailing: Trivia =
        braceTrailing.isEmpty && firstLeading.isEmpty ? .space : braceTrailing
    let closure = ClosureExprSyntax(
        leftBrace: .leftBraceToken(leadingTrivia: .space),
        signature: ClosureSignatureSyntax(
            parameterClause: .simpleInput(
                ClosureShorthandParameterListSyntax([
                    ClosureShorthandParameterSyntax(
                        name: pattern.identifier.with(\.leadingTrivia, .space).with(
                            \.trailingTrivia,
                            []
                        )
                    )
                ])
            ),
            inKeyword: .keyword(.in, leadingTrivia: .space, trailingTrivia: inTrailing)
        ),
        statements: loop.body.statements,
        rightBrace: loop.body.rightBrace.with(\.leadingTrivia, loop.body.rightBrace.leadingTrivia)
    )

    let call = FunctionCallExprSyntax(
        calledExpression: ExprSyntax(
            MemberAccessExprSyntax(base: receiver, name: .identifier("forEach"))
        ),
        leftParen: nil,
        arguments: LabeledExprListSyntax([]),
        rightParen: nil,
        trailingClosure: closure
    )
    return ExprSyntax(call)
        .with(\.leadingTrivia, loop.leadingTrivia)
        .with(\.trailingTrivia, loop.trailingTrivia)
}

internal final class IdiomIterationIntentRewriter: SyntaxRewriter {
    var changed: Swift::Bool = false

    override func visit(_ node: CodeBlockItemSyntax) -> CodeBlockItemSyntax {
        guard case .stmt(let statement) = node.item,
            let loop = statement.as(ForStmtSyntax.self),
            idiomIterationIntentIsFixable(loop),
            let call = idiomIterationIntentCall(for: loop)
        else {
            return super.visit(node)
        }
        changed = true
        return super.visit(node.with(\.item, .expr(call)))
    }
}
