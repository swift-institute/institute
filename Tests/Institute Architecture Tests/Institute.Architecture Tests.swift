import Institute_Architecture_Candidates
import Institute_Architecture_Facts
import Institute_Architecture_Graph
import Institute_Architecture_Index
import Institute_Architecture_Migration
import Institute_Architecture_Model
import Institute_Architecture_Validation
import Institute_Model
import Testing

// MARK: Bounded fixtures

private func owner(
    _ organization: Swift.String,
    _ name: Swift.String
)
    -> Institute.Architecture.Owner
{
    .init(organization: organization, name: name)
}

private func fact(
    _ organization: Swift.String,
    _ name: Swift.String,
    layer: Institute.Architecture.Layer,
    products: [Swift.String] = ["Library"],
    concept: Swift.String? = nil
) -> Institute.Architecture.Fact {
    let owner = owner(organization, name)
    return .init(
        owner: owner,
        layer: layer,
        concept: .init(
            identifier: concept.map { .init(rawValue: $0) } ?? .init(owner: owner),
            name: name
        ),
        products: products,
        targets: products
    )
}

private let today = Institute.Architecture.Exemption.Expiry.fixture("2026-08-07")

/// The bounded positive fixture: derived owner, layer and generated
/// projection agree.
private let positive: [Institute.Architecture.Fact] = [
    fact("swift-atoms", "swift-byte-primitives", layer: .atoms),
    fact("swift-standards", "swift-spm-standard", layer: .standards),
    fact("swift-compositions", "swift-console", layer: .compositions),
]

private let positiveEdges: [Institute.Architecture.Edge] = [
    .init(
        source: owner("swift-compositions", "swift-console"),
        destination: owner("swift-atoms", "swift-byte-primitives"),
        kind: .runtime
    ),
    .init(
        source: owner("swift-standards", "swift-spm-standard"),
        destination: owner("swift-atoms", "swift-byte-primitives"),
        kind: .target
    ),
]

@Suite
struct `Institute Architecture Tests` {
    @Suite
    struct Unit {
        // MARK: Positive control

        @Test
        func `accepts a fixture whose derived owner, layer and projection agree`() {
            let graph = Institute.Architecture.Graph(facts: positive, edges: positiveEdges)
            let report = Institute.Architecture.Validator().validate(
                facts: positive,
                graph: graph,
                today: today
            )
            #expect(report.passes)
            #expect(report.violations.isEmpty)
            #expect(graph.cycle() == nil)
        }

        // MARK: Negative controls

        @Test
        func `rejects a duplicate semantic owner`() {
            let duplicated =
                positive + [
                    fact(
                        "swift-standards",
                        "swift-bytes-standard",
                        layer: .standards,
                        concept: "swift-atoms/swift-byte-primitives"
                    ),
                    fact(
                        "swift-atoms",
                        "swift-byte-primitives-2",
                        layer: .atoms,
                        concept: "swift-atoms/swift-byte-primitives"
                    ),
                ]
            let graph = Institute.Architecture.Graph(facts: duplicated, edges: [])
            let report = Institute.Architecture.Validator().validate(
                facts: duplicated,
                graph: graph,
                today: today
            )
            #expect(!report.passes)
            #expect(
                report.violations.contains { violation in
                    if case .duplicateSemanticOwner = violation { true } else { false }
                }
            )
        }

        @Test
        func `rejects a forbidden dependency edge`() {
            let inverted =
                positiveEdges + [
                    .init(
                        source: owner("swift-atoms", "swift-byte-primitives"),
                        destination: owner("swift-compositions", "swift-console"),
                        kind: .runtime
                    )
                ]
            let graph = Institute.Architecture.Graph(facts: positive, edges: inverted)
            let report = Institute.Architecture.Validator().validate(
                facts: positive,
                graph: graph,
                today: today
            )
            #expect(!report.passes)
            #expect(
                report.violations.contains { violation in
                    if case .forbiddenEdge = violation { true } else { false }
                }
            )
        }

        @Test
        func `finds a derived contradiction for an unknown edge endpoint`() {
            let dangling = [
                Institute.Architecture.Edge(
                    source: owner("swift-compositions", "swift-console"),
                    destination: owner("swift-atoms", "swift-never-derived"),
                    kind: .runtime
                )
            ]
            let graph = Institute.Architecture.Graph(facts: positive, edges: dangling)
            let report = Institute.Architecture.Validator().validate(
                facts: positive,
                graph: graph,
                today: today
            )
            #expect(
                report.violations.contains { violation in
                    if case .contradiction(.unknownEdgeEndpoint) = violation {
                        true
                    } else {
                        false
                    }
                }
            )
        }

        // MARK: Near-miss control

        @Test
        func
            `does not treat a similarly named target as the same concept without a matching concept identifier`()
        {
            let similar = [
                fact("swift-atoms", "swift-json-primitives", layer: .atoms),
                fact("swift-standards", "swift-json-standard", layer: .standards),
            ]
            let graph = Institute.Architecture.Graph(facts: similar, edges: [])
            let report = Institute.Architecture.Validator().validate(
                facts: similar,
                graph: graph,
                today: today
            )
            // Similar names with distinct concept identifiers are NOT a
            // duplicate-owner violation...
            #expect(report.passes)
            // ...they are exactly one advisory candidate.
            let candidates = Institute.Architecture.CandidateDetector().detect(in: similar)
            #expect(candidates.count == 1)
            #expect(candidates.first?.stem == "json")
            #expect(candidates.first?.concepts.count == 2)
        }

        // MARK: Exemption control

        @Test
        func `accepts only a derived-model exemption with owner, reason, scope and expiry`() throws
        {
            let inverted = [
                Institute.Architecture.Edge(
                    source: owner("swift-atoms", "swift-byte-primitives"),
                    destination: owner("swift-compositions", "swift-console"),
                    kind: .runtime
                )
            ]
            let graph = Institute.Architecture.Graph(facts: positive, edges: inverted)

            let exemption = try Institute.Architecture.Exemption(
                owner: owner("swift-atoms", "swift-byte-primitives"),
                reason: "bounded migration window ruled in the accepted programme",
                scope: .forbiddenEdge,
                expiry: .init(rawValue: "2027-01-01")
            )
            let excusedReport = Institute.Architecture.Validator(exemptions: [exemption])
                .validate(facts: positive, graph: graph, today: today)
            #expect(excusedReport.passes)
            #expect(excusedReport.excused.count == 1)

            // An expired exemption excuses nothing.
            let expired = try Institute.Architecture.Exemption(
                owner: owner("swift-atoms", "swift-byte-primitives"),
                reason: "bounded migration window ruled in the accepted programme",
                scope: .forbiddenEdge,
                expiry: .init(rawValue: "2026-01-01")
            )
            let expiredReport = Institute.Architecture.Validator(exemptions: [expired])
                .validate(facts: positive, graph: graph, today: today)
            #expect(!expiredReport.passes)

            // A missing reason cannot be constructed at all.
            #expect(throws: Institute.Architecture.Exemption.Error.self) {
                try Institute.Architecture.Exemption(
                    owner: owner("swift-atoms", "swift-byte-primitives"),
                    reason: "",
                    scope: .forbiddenEdge,
                    expiry: .init(rawValue: "2027-01-01")
                )
            }

            // A malformed expiry cannot be constructed either.
            #expect(throws: Institute.Architecture.Exemption.Error.self) {
                try Institute.Architecture.Exemption.Expiry(rawValue: "someday")
            }
        }
    }

    @Suite
    struct `Edge Case` {
        @Test
        func `classifies a package with zero public APIs`() {
            let closed = fact(
                "swift-atoms",
                "swift-internal-only",
                layer: .atoms,
                products: []
            )
            #expect(closed.classification == .internalOnly)
            #expect(positive[0].classification == .exposesPublicAPI)
        }

        @Test
        func `classifies a migration epoch with zero consumers as terminal`() {
            let terminal = Institute.Architecture.Epoch(
                identifier: .init(rawValue: "epoch-1"),
                owner: owner("swift-atoms", "swift-byte-primitives"),
                consumers: []
            )
            #expect(Institute.Architecture.Migration.classify(terminal) == .terminal)
            let receipt = Institute.Architecture.Migration.receipt(for: terminal)
            #expect(receipt.phase == .terminal)
            #expect(receipt.consumers.isEmpty)

            let active = Institute.Architecture.Epoch(
                identifier: .init(rawValue: "epoch-2"),
                owner: owner("swift-atoms", "swift-byte-primitives"),
                consumers: [owner("swift-compositions", "swift-console")]
            )
            #expect(
                Institute.Architecture.Migration.classify(active) == .active(consumers: 1)
            )
        }
    }

    @Suite
    struct Integration {
        @Test
        func `regenerates the index twice with identical digest`() {
            let graph = Institute.Architecture.Graph(facts: positive, edges: positiveEdges)
            let first = Institute.Architecture.Index.generate(facts: positive, graph: graph)
            let second = Institute.Architecture.Index.generate(
                facts: positive.reversed(),
                graph: graph
            )
            #expect(first.digest == second.digest)
            #expect(first.rendered == second.rendered)
            #expect(!first.rendered.isEmpty)
        }
    }
}
