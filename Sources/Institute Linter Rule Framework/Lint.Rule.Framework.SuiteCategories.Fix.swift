internal import Lint
internal import SwiftSyntax

internal func frameworkSuiteCategoriesFixed(
    _ source: borrowing Lint.Source.Parsed
) -> Swift::String? {
    let rewriter = FrameworkSuiteCategoriesRewriter()
    let rewritten = rewriter.visit(source.tree)
    guard rewriter.changed else { return nil }
    return rewritten.description
}

internal func frameworkSuiteCategoriesIsFixEligible(
    _ memberBlock: MemberBlockSyntax,
    missingBareNames: [Swift::String]
) -> Swift::Bool {
    let missing = Swift::Set(missingBareNames)
    for member in memberBlock.members {
        let decl = member.decl
        if decl.is(IfConfigDeclSyntax.self) {
            return false
        }
        if let functionDecl = decl.as(FunctionDeclSyntax.self),
            frameworkSuiteCategoriesHasTestAttribute(functionDecl.attributes)
        {
            return false
        }
        for name in frameworkSuiteCategoriesDeclaredNames(decl) where missing.contains(name) {
            return false
        }
    }
    return true
}

private func frameworkSuiteCategoriesHasTestAttribute(
    _ attributes: AttributeListSyntax
) -> Swift::Bool {
    for attribute in attributes {
        guard let attr = attribute.as(AttributeSyntax.self) else { continue }
        let name = attr.attributeName.trimmedDescription
        if name == "Test" || name.hasSuffix(".Test") {
            return true
        }
    }
    return false
}

private func frameworkSuiteCategoriesDeclaredNames(_ decl: DeclSyntax) -> [Swift::String] {
    if let d = decl.as(StructDeclSyntax.self) {
        return [Lint.Syntax.Identifier.unescaped(d.name.text)]
    }
    if let d = decl.as(ClassDeclSyntax.self) {
        return [Lint.Syntax.Identifier.unescaped(d.name.text)]
    }
    if let d = decl.as(EnumDeclSyntax.self) {
        return [Lint.Syntax.Identifier.unescaped(d.name.text)]
    }
    if let d = decl.as(ActorDeclSyntax.self) {
        return [Lint.Syntax.Identifier.unescaped(d.name.text)]
    }
    if let d = decl.as(ProtocolDeclSyntax.self) {
        return [Lint.Syntax.Identifier.unescaped(d.name.text)]
    }
    if let d = decl.as(TypeAliasDeclSyntax.self) {
        return [Lint.Syntax.Identifier.unescaped(d.name.text)]
    }
    if let d = decl.as(FunctionDeclSyntax.self) {
        return [Lint.Syntax.Identifier.unescaped(d.name.text)]
    }
    if let d = decl.as(VariableDeclSyntax.self) {
        return d.bindings.compactMap { binding in
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self) else { return nil }
            return Lint.Syntax.Identifier.unescaped(pattern.identifier.text)
        }
    }
    if let d = decl.as(EnumCaseDeclSyntax.self) {
        return d.elements.map { Lint.Syntax.Identifier.unescaped($0.name.text) }
    }
    return []
}

private func frameworkSuiteCategoriesBareName(_ name: Swift::String) -> Swift::String {
    guard name.hasPrefix("`"), name.hasSuffix("`"), name.count >= 2 else { return name }
    return Swift::String(name.dropFirst().dropLast())
}

private func frameworkSuiteCategoriesInsertedStruct(
    _ bareName: Swift::String
) -> MemberBlockItemSyntax {
    let nameText = bareName.contains(" ") ? "`\(bareName)`" : bareName
    let decl = StructDeclSyntax(
        leadingTrivia: .newline + .spaces(4),
        attributes: AttributeListSyntax([
            .attribute(
                AttributeSyntax(
                    attributeName: IdentifierTypeSyntax(name: .identifier("Suite")),
                    trailingTrivia: .space
                )
            )
        ]),
        structKeyword: .keyword(.struct, trailingTrivia: .space),
        name: .identifier(nameText, trailingTrivia: .space),
        memberBlock: MemberBlockSyntax(
            leftBrace: .leftBraceToken(),
            members: MemberBlockItemListSyntax([]),
            rightBrace: .rightBraceToken()
        )
    )
    return MemberBlockItemSyntax(decl: DeclSyntax(decl))
}

internal final class FrameworkSuiteCategoriesRewriter: SyntaxRewriter {
    var changed: Swift::Bool = false

    override func visit(_ node: StructDeclSyntax) -> DeclSyntax {
        guard suiteCategoriesHasSuiteAttribute(node.attributes) else { return super.visit(node) }
        guard suiteCategoriesIsTopLevel(Syntax(node)) else { return super.visit(node) }
        let missing = suiteCategoriesMissingFromBody(node.memberBlock)
        guard !missing.isEmpty else { return super.visit(node) }
        let missingBareNames = missing.map(frameworkSuiteCategoriesBareName)
        guard
            frameworkSuiteCategoriesIsFixEligible(
                node.memberBlock,
                missingBareNames: missingBareNames
            )
        else {
            return super.visit(node)
        }
        changed = true
        let existing = Swift::Array(node.memberBlock.members)
        let inserted = missingBareNames.map(frameworkSuiteCategoriesInsertedStruct)
        let newBlock = node.memberBlock.with(
            \.members,
            MemberBlockItemListSyntax(existing + inserted)
        )
        return super.visit(node.with(\.memberBlock, newBlock))
    }
}
