public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture {
    /// The derived model: every fact and every typed edge, in canonical
    /// order.
    ///
    /// Derivation is pure and deterministic — the same inventory and the
    /// same manifests always produce the same `Facts`, which is what makes
    /// the generated index and projection reproducible.
    public struct Facts: Sendable, Equatable {
        public let facts: [Fact]
        public let edges: [Edge]
        public let coverage: Coverage

        public init(
            facts: [Fact],
            edges: [Edge],
            coverage: Coverage? = nil
        ) {
            self.facts = facts.sorted()
            self.edges = edges.sorted()
            self.coverage =
                coverage
                ?? .init(
                    required: facts.map(\.owner),
                    measured: facts.map(\.owner)
                )
        }
    }
}

extension Institute.Architecture.Facts {
    /// The inventory coordinate every provenance edge points at: the
    /// package root whose `Institute.json` supplied the rows.
    public static let inventoryOwner = Institute.Architecture.Owner(
        organization: "swift-institute",
        name: "institute-application"
    )

    /// Derives the model from a decoded inventory and the manifests that
    /// were locally readable.
    ///
    /// Every readable manifest yields one fact and provenance edge. An
    /// unreadable manifest remains in `Coverage.unmeasured`, never as an
    /// empty product/target fact.
    public static func derive(
        inventory: Inventory,
        manifests: [Institute.Architecture.Owner: Manifest]
    ) -> Self {
        let owners = Swift.Dictionary(
            uniqueKeysWithValues: inventory.rows.map { row in
                ("\(row.organization)/\(row.name)", row.owner)
            }
        )
        var facts: [Institute.Architecture.Fact] = []
        var edges: [Institute.Architecture.Edge] = []
        var measured: [Institute.Architecture.Owner] = []
        for row in inventory.rows {
            guard let manifest = manifests[row.owner] else { continue }
            measured.append(row.owner)
            facts.append(
                .init(
                    owner: row.owner,
                    layer: row.layer,
                    concept: .init(
                        identifier: .init(owner: row.owner),
                        name: row.name
                    ),
                    products: manifest.products,
                    targets: manifest.targets
                )
            )
            edges.append(
                .init(source: row.owner, destination: inventoryOwner, kind: .provenance)
            )
            for url in manifest.dependencyURLs {
                guard
                    let coordinate = Manifest.coordinate(url: url),
                    let destination = owners[coordinate],
                    destination != row.owner
                else { continue }
                edges.append(
                    .init(source: row.owner, destination: destination, kind: .runtime)
                )
            }
        }
        return .init(
            facts: facts,
            edges: Swift.Array(Swift.Set(edges)),
            coverage: .init(
                required: inventory.rows.map(\.owner),
                measured: measured
            )
        )
    }
}
