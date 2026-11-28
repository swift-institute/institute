extension ManifestSourceFacts.Declaration {
    package enum Kind: Sendable, Equatable {
        case type
        case alias
        case macro
    }
}
