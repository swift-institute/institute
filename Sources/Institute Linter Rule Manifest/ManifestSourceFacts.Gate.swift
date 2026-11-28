internal import SwiftSyntax

extension ManifestSourceFacts {
    /// How a file's content is wrapped in conditional compilation.
    package enum Gate: Sendable, Equatable {
        /// The file holds nothing but imports.
        case none
        /// Every declaration of the file is inside an `#if` whose first condition names these identifiers.
        case gated(Swift::Set<Swift::String>)
        /// Some of the file's content is outside any `#if`.
        case open
    }
}

extension ManifestSourceFacts.Gate {
    init(statements: CodeBlockItemListSyntax) {
        var identifiers: Swift::Set<Swift::String> = []
        var content = false
        for statement in statements {
            if statement.item.as(ImportDeclSyntax.self) != nil { continue }
            content = true
            guard let conditional = statement.item.as(IfConfigDeclSyntax.self),
                let condition = conditional.clauses.first?.condition
            else {
                self = .open
                return
            }
            for token in condition.tokens(viewMode: .sourceAccurate) {
                if case .identifier(let name) = token.tokenKind { identifiers.insert(name) }
            }
        }
        self = content ? .gated(identifiers) : .none
    }
}
