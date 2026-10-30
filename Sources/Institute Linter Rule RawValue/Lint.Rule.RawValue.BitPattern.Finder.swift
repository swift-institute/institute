internal import SwiftSyntax

internal final class RawValueBitPatternFinder: SyntaxVisitor {
    var found: Swift::Bool = false

    override func visit(_ node: MemberAccessExprSyntax) -> SyntaxVisitorContinueKind {
        if node.declName.baseName.text == "rawValue" {
            found = true
            return .skipChildren
        }
        return .visitChildren
    }
}
