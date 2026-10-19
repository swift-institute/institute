public import Institute_Architecture_Graph
public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture.Facts {
    /// The canonical dependency graph reconstructed from these facts.
    ///
    /// Provenance records explain how a fact was measured; they are not
    /// package-to-package dependencies and their inventory endpoint is not
    /// an indexed package root. The Architecture Index therefore transports
    /// this graph, whose every endpoint is an indexed owner.
    public var graph: Institute.Architecture.Graph {
        .init(
            facts: facts,
            edges: edges.filter { $0.kind != .provenance }
        )
    }
}
