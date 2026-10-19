import Institute_Architecture_Facts
import Institute_Architecture_Graph
import Institute_Architecture_Index
import Institute_Architecture_Model
import Institute_Model
import JSON
import Testing

private let inventory = Institute.Architecture.Facts.Inventory(rows: [
    .init(
        organization: "swift-atoms",
        name: "swift-byte-primitives",
        layer: .atoms,
        url: "https://github.com/swift-atoms/swift-byte-primitives.git"
    ),
    .init(
        organization: "swift-compositions",
        name: "swift-console",
        layer: .compositions,
        url: "https://github.com/swift-compositions/swift-console.git"
    ),
])

private let manifest = Institute.Architecture.Facts.Manifest.scan(
    """
    let package = Package(
        name: "swift-console",
        products: [
            .library(
                name: "Console",
                targets: ["Console"]
            ),
        ],
        dependencies: [
            .package(url: "https://github.com/swift-atoms/swift-byte-primitives.git", branch: "main"),
        ],
        targets: [
            .target(
                name: "Console"
            ),
            .testTarget(
                name: "Console Tests",
                dependencies: ["Console"]
            ),
        ]
    )
    """
)

@Suite
struct `Institute Architecture Facts Tests` {
    @Suite
    struct Unit {
        @Test
        func `scans a manifest for targets, products and dependency URLs`() {
            #expect(manifest.products == ["Console"])
            #expect(manifest.targets == ["Console"])
            #expect(
                manifest.dependencyURLs
                    == ["https://github.com/swift-atoms/swift-byte-primitives.git"]
            )
        }

        @Test
        func `derives facts, provenance edges and runtime edges`() {
            let consoleOwner = Institute.Architecture.Owner(
                organization: "swift-compositions",
                name: "swift-console"
            )
            let derived = Institute.Architecture.Facts.derive(
                inventory: inventory,
                manifests: [consoleOwner: manifest]
            )
            #expect(derived.facts.count == 1)
            #expect(
                derived.edges.contains { edge in
                    edge.kind == .provenance
                        && edge.destination == Institute.Architecture.Facts.inventoryOwner
                }
            )
            #expect(
                derived.edges.contains(
                    .init(
                        source: consoleOwner,
                        destination: .init(
                            organization: "swift-atoms",
                            name: "swift-byte-primitives"
                        ),
                        kind: .runtime
                    )
                )
            )
            // The console fact carries manifest-derived products.
            let console = derived.facts.first { $0.owner == consoleOwner }
            #expect(console?.products == ["Console"])
            #expect(console?.classification == .exposesPublicAPI)
            #expect(derived.graph.edges.allSatisfy { $0.kind != .provenance })
            #expect(
                derived.graph.edges.contains(
                    .init(
                        source: consoleOwner,
                        destination: .init(
                            organization: "swift-atoms",
                            name: "swift-byte-primitives"
                        ),
                        kind: .runtime
                    )
                )
            )
        }

        @Test
        func `keeps unreadable manifests as coverage gaps instead of empty facts`() {
            let derived = Institute.Architecture.Facts.derive(
                inventory: inventory,
                manifests: [:]
            )

            #expect(derived.facts.isEmpty)
            #expect(!derived.coverage.complete)
            #expect(derived.coverage.unmeasured == inventory.rows.map(\.owner).sorted())
        }

        @Test
        func `records an empty measured manifest as an internal-only fact`() {
            let owner = Institute.Architecture.Owner(
                organization: "swift-atoms",
                name: "swift-byte-primitives"
            )
            let derived = Institute.Architecture.Facts.derive(
                inventory: .init(rows: [inventory.rows[0]]),
                manifests: [
                    owner: .init(targets: [], products: [], dependencyURLs: [])
                ]
            )

            #expect(derived.coverage.complete)
            #expect(derived.facts.first?.classification == .internalOnly)
        }
    }

    @Suite
    struct `Edge Case` {
        @Test
        func `decodes an inventory document and ignores unrelated keys`() throws {
            let decoded = try Institute.Architecture.Facts.Inventory(
                jsonString: """
                    {
                      "repositories": [
                        {
                          "layer": "standards",
                          "name": "swift-spm-standard",
                          "organization": "swift-standards",
                          "url": "https://github.com/swift-standards/swift-spm-standard.git"
                        }
                      ],
                      "scope": "proof",
                      "swift": "6.3.3",
                      "version": 1,
                      "xcode": "26.6"
                    }
                    """
            )
            #expect(decoded.rows.count == 1)
            #expect(decoded.rows.first?.layer == .standards)
            #expect(
                decoded.rows.first?.owner
                    == .init(organization: "swift-standards", name: "swift-spm-standard")
            )
        }
    }

    @Suite
    struct Integration {
        @Test
        func `derivation is deterministic across repeated runs`() {
            let consoleOwner = Institute.Architecture.Owner(
                organization: "swift-compositions",
                name: "swift-console"
            )
            let first = Institute.Architecture.Facts.derive(
                inventory: inventory,
                manifests: [consoleOwner: manifest]
            )
            let second = Institute.Architecture.Facts.derive(
                inventory: inventory,
                manifests: [consoleOwner: manifest]
            )
            #expect(first == second)
            let graph = Institute.Architecture.Graph(facts: first.facts, edges: first.edges)
            #expect(
                Institute.Architecture.Index.generate(facts: first.facts, graph: graph).digest
                    == Institute.Architecture.Index.generate(
                        facts: second.facts,
                        graph: graph
                    )
                    .digest
            )
        }
    }
}
