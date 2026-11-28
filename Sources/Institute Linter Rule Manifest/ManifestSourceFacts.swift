package import SwiftSyntax

/// What one source file declares that the package rules read: whether it declares anything at all, the types,
/// typealiases and macros it declares with their dotted paths, and the traits its content is gated by.
package struct ManifestSourceFacts: Sendable {
    /// Whether the file holds only imports, or imports and namespace enums with no cases and no members.
    package let empty: Swift::Bool
    package let declarations: [Declaration]
    package let gate: Gate
}

extension ManifestSourceFacts {
    package init(tree: SourceFileSyntax) {
        var walker = Walker()
        walker.statements(tree.statements, scope: .init())
        self.empty = walker.empty
        self.declarations = walker.declarations
        self.gate = Gate(statements: tree.statements)
    }
}
