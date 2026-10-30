internal import SwiftParser
internal import SwiftSyntax

internal final class NamingMacroExpansionShortNameFinder: SyntaxVisitor {
    var matches: [(literal: StringLiteralExprSyntax, name: Swift::String)] = []

    override func visit(_: FunctionDeclSyntax) -> SyntaxVisitorContinueKind {
        .skipChildren
    }

    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        let generatedSource = namingMacroExpansionShortNameGeneratedSource(node)
        let parsed = Parser.parse(source: generatedSource)
        let typeFinder = NamingMacroExpansionShortNameTypeFinder(viewMode: .sourceAccurate)
        typeFinder.walk(parsed)
        for name in typeFinder.matches {
            matches.append((literal: node, name: name))
        }
        return .skipChildren
    }
}

private func namingMacroExpansionShortNameGeneratedSource(
    _ node: StringLiteralExprSyntax
) -> Swift::String {
    var source = ""
    for segment in node.segments {
        switch segment {
        case .stringSegment(let text):
            source += text.content.text
        case .expressionSegment:
            source += "__macro_interpolation__"
        }
    }
    return source
}
