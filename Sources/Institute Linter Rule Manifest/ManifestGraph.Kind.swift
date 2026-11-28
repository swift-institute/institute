extension ManifestGraph {
    package enum Kind: Sendable, Equatable {
        case regular
        case macro
        case executable
        case test
        case other
    }
}
