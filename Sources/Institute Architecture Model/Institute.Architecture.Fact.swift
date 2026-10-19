public import Institute_Model

extension Institute.Architecture {
    /// The derived facts about one package root.
    ///
    /// A fact records what live sources actually say — inventory row,
    /// manifest targets and products — and nothing an author asserted.
    public struct Fact: Sendable, Equatable, Hashable {
        public let owner: Owner
        public let layer: Layer
        public let concept: Concept
        public let products: [Swift.String]
        public let targets: [Swift.String]

        public init(
            owner: Owner,
            layer: Layer,
            concept: Concept,
            products: [Swift.String],
            targets: [Swift.String]
        ) {
            self.owner = owner
            self.layer = layer
            self.concept = concept
            self.products = products
            self.targets = targets
        }
    }
}

extension Institute.Architecture.Fact {
    /// How the package presents itself to consumers.
    ///
    /// A package with zero products exposes zero public APIs; it is a valid,
    /// classifiable state, not an error.
    public var classification: Classification {
        products.isEmpty ? .internalOnly : .exposesPublicAPI
    }
}

extension Institute.Architecture.Fact: Comparable {
    public static func < (
        lhs: Institute.Architecture.Fact,
        rhs: Institute.Architecture.Fact
    ) -> Swift.Bool {
        lhs.owner < rhs.owner
    }
}
