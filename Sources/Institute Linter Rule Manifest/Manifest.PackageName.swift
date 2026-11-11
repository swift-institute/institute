internal import Lint
internal import Linter_Rule_Scope
internal import SwiftParser
internal import SwiftSyntax

/// The package name the manifest one folder above `filePath`'s folder declares, or `nil` when that folder holds no
/// `Package.swift` or the name isn't a string literal.
internal func manifestParentPackageName(_ filePath: Swift::String) -> Swift::String? {
    guard let manifestSlash = filePath.lastIndex(of: "/") else { return nil }
    let folder = filePath[..<manifestSlash]
    guard let folderSlash = folder.lastIndex(of: "/") else { return nil }
    let parent = Swift::String(folder[..<folderSlash]) + "/Package.swift"
    guard Lint.Scope.File.isFile(parent), let text = Lint.Scope.File.text(at: parent) else { return nil }
    let visitor = ManifestPackageNameVisitor(viewMode: .sourceAccurate)
    visitor.walk(Parser.parse(source: text))
    return visitor.name
}

/// Finds the `name:` of a manifest's `Package(…)`.
internal final class ManifestPackageNameVisitor: SyntaxVisitor {
    var name: Swift::String?

    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        guard name == nil,
            node.calledExpression.as(DeclReferenceExprSyntax.self)?.baseName.text == "Package",
            let argument = node.arguments.first(where: { $0.label?.text == "name" }),
            let literal = argument.expression.as(StringLiteralExprSyntax.self)
        else { return .visitChildren }
        name = manifestStringLiteralText(literal)
        return .skipChildren
    }
}
