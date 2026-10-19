public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture.CandidateDetector {
    /// One advisory finding: name-similar owners with distinct concept
    /// identities.
    ///
    /// A candidate proposes a human look; it never merges concepts.
    public struct Candidate: Sendable, Equatable {
        public let stem: Swift.String
        public let owners: [Institute.Architecture.Owner]
        public let concepts: [Institute.Architecture.Concept.Identifier]

        public init(
            stem: Swift.String,
            owners: [Institute.Architecture.Owner],
            concepts: [Institute.Architecture.Concept.Identifier]
        ) {
            self.stem = stem
            self.owners = owners
            self.concepts = concepts
        }
    }
}
