public import Institute_Architecture_Facts
public import Institute_Architecture_Graph
public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture {
    /// Class I validation of the derived model.
    ///
    /// Every check is mechanically decidable from facts and graph alone:
    /// duplicate semantic owners, forbidden edges, and derived
    /// contradiction checks. Exemptions are derived-model exemptions —
    /// owner, reason, scope, expiry — and excuse exactly the violations
    /// whose scope and owner they name, until they expire.
    public struct Validator: Sendable {
        public let exemptions: [Exemption]

        public init(exemptions: [Exemption] = []) {
            self.exemptions = exemptions
        }
    }
}

extension Institute.Architecture.Validator {
    /// Validates a complete derived population and its canonical graph.
    ///
    /// Measurement gaps are never excusable: a missing manifest means the
    /// relevant architecture fact and its dependencies were not observed.
    public func validate(
        derived: Institute.Architecture.Facts,
        today: Institute.Architecture.Exemption.Expiry
    ) -> Report {
        let graph = derived.graph
        let report = findings(facts: derived.facts, graph: graph, today: today)
        let gaps = derived.coverage.unmeasured.map {
            Institute.Architecture.Violation.contradiction(.unmeasuredManifest($0))
        }
        return .init(
            derived: derived,
            graph: graph,
            violations: report.violations + gaps,
            excused: report.excused
        )
    }

    /// Validates the derived model as of `today`.
    public func validate(
        facts: [Institute.Architecture.Fact],
        graph: Institute.Architecture.Graph,
        today: Institute.Architecture.Exemption.Expiry
    ) -> Report {
        validate(
            derived: .init(facts: facts, edges: graph.edges),
            today: today
        )
    }

    private func findings(
        facts: [Institute.Architecture.Fact],
        graph: Institute.Architecture.Graph,
        today: Institute.Architecture.Exemption.Expiry
    ) -> (
        violations: [Institute.Architecture.Violation], excused: [Institute.Architecture.Violation]
    ) {
        var violations: [Institute.Architecture.Violation] = []

        var claims: [Institute.Architecture.Concept.Identifier: [Institute.Architecture.Owner]] =
            [:]
        for fact in facts {
            claims[fact.concept.identifier, default: []].append(fact.owner)
        }
        for (concept, owners) in claims.sorted(by: { $0.key < $1.key }) where owners.count > 1 {
            violations.append(
                .duplicateSemanticOwner(concept: concept, owners: owners.sorted())
            )
        }

        for forbidden in graph.forbiddenEdges {
            violations.append(
                .forbiddenEdge(
                    forbidden.edge,
                    source: forbidden.source,
                    destination: forbidden.destination
                )
            )
        }

        let known = Swift.Set(facts.map(\.owner))
        for edge in graph.edges {
            if !known.contains(edge.source) {
                violations.append(
                    .contradiction(.unknownEdgeEndpoint(edge, missing: edge.source))
                )
            }
            if !known.contains(edge.destination), edge.kind != .provenance {
                violations.append(
                    .contradiction(.unknownEdgeEndpoint(edge, missing: edge.destination))
                )
            }
        }
        for fact in facts {
            if let placed = graph.layers[fact.owner], placed != fact.layer {
                violations.append(
                    .contradiction(
                        .layerDisagreement(
                            owner: fact.owner,
                            inventory: fact.layer,
                            derived: placed
                        )
                    )
                )
            }
        }

        var outstanding: [Institute.Architecture.Violation] = []
        var excused: [Institute.Architecture.Violation] = []
        for violation in violations {
            let covered = exemptions.contains { exemption in
                exemption.scope == violation.scope
                    && violation.owners.contains(exemption.owner)
                    && exemption.expiry >= today
            }
            if covered {
                excused.append(violation)
            } else {
                outstanding.append(violation)
            }
        }
        return (violations: outstanding, excused: excused)
    }
}
