public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture.Index {
    /// One index row: the derived summary of a single package root.
    public struct Entry: Sendable, Equatable {
        public let owner: Institute.Architecture.Owner
        public let layer: Institute.Architecture.Layer
        public let concept: Institute.Architecture.Concept.Identifier
        public let productCount: Swift.Int
        public let targetCount: Swift.Int
        public let edgeCount: Swift.Int

        public init(
            owner: Institute.Architecture.Owner,
            layer: Institute.Architecture.Layer,
            concept: Institute.Architecture.Concept.Identifier,
            productCount: Swift.Int,
            targetCount: Swift.Int,
            edgeCount: Swift.Int
        ) {
            self.owner = owner
            self.layer = layer
            self.concept = concept
            self.productCount = productCount
            self.targetCount = targetCount
            self.edgeCount = edgeCount
        }
    }
}
