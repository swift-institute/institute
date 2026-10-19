public import Institute_Architecture_Facts
public import Institute_Architecture_Graph
public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture.Index.Artifact {
    /// The exact canonical bytes represented as UTF-8 text.
    public var rendered: Swift.String {
        "digest\t\(digest)\n"
            + Self.payload(
                index: index,
                edges: edges,
                coverage: coverage
            )
    }

    static func payload(
        index: Institute.Architecture.Index,
        edges: [Institute.Architecture.Edge],
        coverage: Institute.Architecture.Facts.Coverage
    ) -> Swift.String {
        let header = [
            "schema\t\(schema)",
            "version\t\(version)",
            "measurement\tcomplete\t\(coverage.measured.count)/\(coverage.required.count)",
            "index-digest\t\(index.digest)",
            "validation\tvalid",
        ]
        let entries = index.entries.map { entry in
            "entry\t\(entry.owner)\t\(entry.layer.name)\t\(entry.concept)"
                + "\tproducts=\(entry.productCount)\ttargets=\(entry.targetCount)"
                + "\tedges=\(entry.edgeCount)"
        }
        let edges = edges.map { edge in
            "edge\t\(edge.kind.name)\t\(edge.source)\t\(edge.destination)"
        }
        return (header + entries + edges).joined(separator: "\n")
    }
}
