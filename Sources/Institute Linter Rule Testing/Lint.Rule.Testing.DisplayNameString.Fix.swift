internal import Lint
internal import SwiftSyntax

internal func testingDisplayNameStringFixed(
    _ source: borrowing Lint.Source.Parsed
) -> Swift::String? {
    let rewriter = TestingDisplayNameStringRewriter()
    let rewritten = rewriter.visit(source.tree)
    guard rewriter.changed else { return nil }
    return rewritten.description
}

internal final class TestingDisplayNameStringRewriter: SyntaxRewriter {
    var changed: Swift::Bool = false

    private func fixed(
        name: TokenSyntax,
        attributes: AttributeListSyntax
    ) -> AttributeListSyntax {
        var elements = Swift::Array(attributes)
        for index in elements.indices {
            guard case .attribute(let attribute) = elements[index] else { continue }
            guard let rewritten = fixed(name: name, attribute: attribute) else { continue }
            elements[index] = .attribute(rewritten)
            changed = true
        }
        return AttributeListSyntax(elements)
    }

    private func fixed(name: TokenSyntax, attribute: AttributeSyntax) -> AttributeSyntax? {
        let attributeName = attribute.attributeName.trimmedDescription
        guard
            ["Test", "Suite"].contains(where: {
                attributeName == $0 || attributeName.hasSuffix(".\($0)")
            })
        else { return nil }
        guard case .argumentList(let arguments) = attribute.arguments else { return nil }
        guard let argument = arguments.first, argument.label == nil else { return nil }
        guard let literal = argument.expression.as(StringLiteralExprSyntax.self) else { return nil }
        guard let content = testingDisplayNameContent(literal) else { return nil }
        guard displayNameCanBeRawIdentifier(content) else { return nil }
        guard testingDisplayNameDuplicatesDeclaration(name: name, content: content) else {
            return nil
        }

        let remaining = Swift::Array(arguments.dropFirst())
        if remaining.isEmpty {
            return removingOnlyArgument(argument, from: attribute)
        }
        return removingLeadingArgument(argument, remaining: remaining, from: attribute)
    }

    private func removingOnlyArgument(
        _ argument: LabeledExprSyntax,
        from attribute: AttributeSyntax
    ) -> AttributeSyntax? {
        guard let leftParen = attribute.leftParen, let rightParen = attribute.rightParen else {
            return nil
        }
        guard attribute.unexpectedBetweenAttributeNameAndLeftParen == nil,
            attribute.unexpectedBetweenLeftParenAndArguments == nil,
            attribute.unexpectedBetweenArgumentsAndRightParen == nil
        else { return nil }

        let carried =
            testingDisplayNameAuthoredTrivia(leftParen.leadingTrivia)
            + testingDisplayNameAuthoredTrivia(leftParen.trailingTrivia)
            + testingDisplayNameAuthoredTrivia(argument.leadingTrivia)
            + testingDisplayNameAuthoredTrivia(argument.trailingTrivia)
            + testingDisplayNameAuthoredTrivia(rightParen.leadingTrivia)
            + rightParen.trailingTrivia
        let name = attribute.attributeName.with(
            \.trailingTrivia,
            attribute.attributeName.trailingTrivia + carried
        )
        return
            attribute
            .with(\.attributeName, name)
            .with(\.leftParen, nil)
            .with(\.arguments, nil)
            .with(\.rightParen, nil)
    }

    private func removingLeadingArgument(
        _ argument: LabeledExprSyntax,
        remaining: [LabeledExprSyntax],
        from attribute: AttributeSyntax
    ) -> AttributeSyntax? {
        guard let leftParen = attribute.leftParen else { return nil }
        guard attribute.unexpectedBetweenLeftParenAndArguments == nil else { return nil }

        let before =
            testingDisplayNameAuthoredTrivia(leftParen.trailingTrivia)
            + testingDisplayNameAuthoredTrivia(argument.leadingTrivia)
        let after = testingDisplayNameLayoutTrivia(argument.trailingTrivia)
        let rewrittenLeftParen = leftParen.with(\.trailingTrivia, before + after)
        return
            attribute
            .with(\.leftParen, rewrittenLeftParen)
            .with(\.arguments, .argumentList(LabeledExprListSyntax(remaining)))
    }

    override func visit(_ node: FunctionDeclSyntax) -> DeclSyntax {
        super.visit(node.with(\.attributes, fixed(name: node.name, attributes: node.attributes)))
    }

    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        super.visit(node.with(\.attributes, fixed(name: node.name, attributes: node.attributes)))
    }

    override func visit(_ node: EnumDeclSyntax) -> DeclSyntax {
        super.visit(node.with(\.attributes, fixed(name: node.name, attributes: node.attributes)))
    }

    override func visit(_ node: ClassDeclSyntax) -> DeclSyntax {
        super.visit(node.with(\.attributes, fixed(name: node.name, attributes: node.attributes)))
    }

    override func visit(_ node: ActorDeclSyntax) -> DeclSyntax {
        super.visit(node.with(\.attributes, fixed(name: node.name, attributes: node.attributes)))
    }
}

private func testingDisplayNameAuthoredTrivia(_ trivia: Trivia) -> Trivia {
    for piece in trivia {
        switch piece {
        case .spaces, .tabs, .newlines, .carriageReturns, .carriageReturnLineFeeds,
            .formfeeds, .verticalTabs:
            continue

        default:
            return trivia
        }
    }
    return []
}

private func testingDisplayNameLayoutTrivia(_ trivia: Trivia) -> Trivia {
    for piece in trivia {
        switch piece {
        case .newlines, .carriageReturns, .carriageReturnLineFeeds:
            return trivia

        case .spaces, .tabs, .formfeeds, .verticalTabs:
            continue

        default:
            return trivia
        }
    }
    return []
}
