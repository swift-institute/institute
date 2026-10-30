internal import SwiftSyntax

internal final class ThrowsPhantomParameterUseFinder: SyntaxVisitor {
    let parameter: Swift::String
    var found = false

    init(parameter: Swift::String) {
        self.parameter = parameter
        super.init(viewMode: .sourceAccurate)
    }

    override func visit(_: GenericArgumentClauseSyntax) -> SyntaxVisitorContinueKind {
        return .skipChildren
    }

    override func visit(_ node: IdentifierTypeSyntax) -> SyntaxVisitorContinueKind {
        if node.name.text == parameter { found = true }
        return .visitChildren
    }
}
