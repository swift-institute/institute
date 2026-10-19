public import Institute_Architecture_Facts
public import Institute_Architecture_Graph
public import Institute_Architecture_Model
public import Institute_Architecture_Validation
public import Institute_Model

extension Institute.Architecture.Index {
    /// A versioned, complete, validated, deterministic Index transport
    /// artifact for downstream host-control consumers.
    public struct Artifact: Sendable, Equatable {
        public let index: Institute.Architecture.Index
        public let edges: [Institute.Architecture.Edge]
        public let coverage: Institute.Architecture.Facts.Coverage
        public let digest: Institute.Architecture.Index.Digest

        public init(
            facts: Institute.Architecture.Facts,
            validation: Institute.Architecture.Validator.Report
        ) throws(Error) {
            guard facts.coverage.complete else {
                throw .incompleteMeasurement(facts.coverage.unmeasured)
            }
            let owners = facts.facts.map(\.owner)
            guard facts.coverage.required == owners, facts.coverage.measured == owners else {
                throw .invalidCoverage
            }
            guard
                facts.facts.allSatisfy({ fact in
                    fact.owner.isCanonical
                        && fact.concept.identifier == .init(owner: fact.owner)
                })
            else {
                throw .invalidFact
            }
            let graph = facts.graph
            guard validation.derived == facts, validation.graph == graph, validation.passes
            else { throw .invalidValidation }
            let edges = Swift.Array(Swift.Set(graph.edges)).sorted()
            let index = Institute.Architecture.Index.generate(
                facts: facts.facts,
                graph: .init(facts: facts.facts, edges: edges)
            )
            let coverage = facts.coverage
            self.index = index
            self.edges = edges
            self.coverage = coverage
            self.digest = .init(
                text: Self.payload(
                    index: index,
                    edges: edges,
                    coverage: coverage
                )
            )
        }
    }
}

extension Institute.Architecture.Index.Artifact {
    /// The stable artifact schema identity.
    public static let schema = "workspace.architecture.index"

    /// The stable artifact schema version.
    public static let version = 1
}
