internal import Lint
internal import Linter_Rule_Scope
internal import SwiftParser
internal import SwiftSyntax

/// The package name the manifest one folder above `filePath`'s folder declares, or `nil` when that folder holds no
/// `Package.swift` or the name isn't a string literal.
internal func manifestParentPackageName(_ filePath: Swift::String) -> Swift::String? {
    guard let parent = manifestParentManifestPath(filePath),
        Lint.Scope.File.isFile(parent),
        let text = Lint.Scope.File.text(at: parent)
    else { return nil }
    let visitor = ManifestPackageNameVisitor(viewMode: .sourceAccurate)
    visitor.walk(Parser.parse(source: text))
    return visitor.name
}

/// The path of the `Package.swift` one folder above the folder of the manifest at `filePath`, or `nil` for a manifest
/// in the file system's root. A relative `filePath` gives a relative path, which the file system reads from the
/// working directory as it does `filePath` itself: `Package.swift` gives `../Package.swift`, and `leaf/Package.swift`
/// gives `Package.swift` (swift-institute/institute#286).
internal func manifestParentManifestPath(_ filePath: Swift::String) -> Swift::String? {
    let path = Swift::String(filePath.map { $0 == "\\" ? "/" : $0 })
    let rooted = path.hasPrefix("/")
    var folder = path.split(separator: "/", omittingEmptySubsequences: true).dropLast().filter { $0 != "." }
    if let last = folder.last, last != ".." {
        folder.removeLast()
    } else if rooted {
        return nil
    } else {
        folder.append("..")
    }
    return (rooted ? "/" : "") + (folder + ["Package.swift"]).joined(separator: "/")
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
