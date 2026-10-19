import Institute_Architecture_Facts
import Institute_Architecture_Graph
import Institute_Architecture_Index
import Institute_Architecture_Model
import Institute_Architecture_Validation
import Institute_Model
import Testing

@Suite
struct `Institute Architecture Index Artifact Tests` {
    @Test
    func `emits complete validated canonical bytes`() throws {
        let artifact = try Artifact.fixture()

        #expect(artifact.rendered.contains("schema\tworkspace.architecture.index"))
        #expect(artifact.rendered.contains("version\t1"))
        #expect(artifact.rendered.contains("measurement\tcomplete\t2/2"))
        #expect(artifact.rendered.contains("index-digest\t\(artifact.index.digest)"))
        #expect(artifact.rendered.contains("validation\tvalid"))
        #expect(
            artifact.rendered.contains(
                "edge\truntime\tswift-compositions/swift-console\tswift-atoms/swift-byte-primitives"
            )
        )
        let owners = Swift.Set(artifact.index.entries.map(\.owner))
        #expect(
            artifact.edges.allSatisfy {
                owners.contains($0.source) && owners.contains($0.destination)
            }
        )
        #expect(
            artifact.index.entries.reduce(0, { $0 + $1.edgeCount }) == artifact.edges.count
        )
        try Artifact.verify(artifact.rendered)
    }

    @Test
    func `regenerates byte-identically from permuted facts`() throws {
        let first = try Artifact.fixture()
        let second = try Artifact.fixture(reversed: true)

        #expect(first.digest == second.digest)
        #expect(first.rendered == second.rendered)
    }

    @Test
    func `canonicalizes duplicate edges into self-verifying bytes`() throws {
        let inputs = Artifact.inputs()
        let edge = try #require(inputs.edges.first)
        let facts = Institute.Architecture.Facts(
            facts: inputs.facts,
            edges: [edge, edge]
        )
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: Artifact.today
        )

        let artifact = try Institute.Architecture.Index.Artifact(
            facts: facts,
            validation: validation
        )

        #expect(artifact.edges == [edge])
        #expect(
            artifact.index.entries.first(where: { $0.owner == edge.source })?.edgeCount == 1
        )
        try Artifact.verify(artifact.rendered)
    }

    @Test
    func `rejects a fact whose concept identifier differs from its owner`() {
        let original = Artifact.fact(
            organization: "swift-atoms",
            name: "swift-byte-primitives",
            layer: .atoms,
            products: ["Byte Primitives"]
        )
        let mismatched = Institute.Architecture.Fact(
            owner: original.owner,
            layer: original.layer,
            concept: .init(
                identifier: .init(rawValue: "swift-atoms/swift-other-primitives"),
                name: original.concept.name
            ),
            products: original.products,
            targets: original.targets
        )
        let facts = Institute.Architecture.Facts(facts: [mismatched], edges: [])
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: Artifact.today
        )

        #expect(validation.passes)
        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            _ = try Institute.Architecture.Index.Artifact(
                facts: facts,
                validation: validation
            )
        }
    }

    @Test(arguments: [
        Institute.Architecture.Owner(organization: "", name: "swift-byte-primitives"),
        Institute.Architecture.Owner(organization: "swift-atoms", name: ""),
        Institute.Architecture.Owner(
            organization: "swift/primitives",
            name: "swift-byte-primitives"
        ),
        Institute.Architecture.Owner(
            organization: "swift-atoms",
            name: "swift/byte-primitives"
        ),
        Institute.Architecture.Owner(
            organization: "swift\tprimitives",
            name: "swift-byte-primitives"
        ),
        Institute.Architecture.Owner(
            organization: "swift-atoms",
            name: "swift\tbyte-primitives"
        ),
        Institute.Architecture.Owner(
            organization: "swift\rprimitives",
            name: "swift-byte-primitives"
        ),
        Institute.Architecture.Owner(
            organization: "swift-atoms",
            name: "swift\rbyte-primitives"
        ),
        Institute.Architecture.Owner(
            organization: "swift\nprimitives",
            name: "swift-byte-primitives"
        ),
        Institute.Architecture.Owner(
            organization: "swift-atoms",
            name: "swift\nbyte-primitives"
        ),
    ])
    func `rejects owners that cannot form canonical artifact coordinates`(
        _ owner: Institute.Architecture.Owner
    ) {
        let fact = Institute.Architecture.Fact(
            owner: owner,
            layer: .atoms,
            concept: .init(identifier: .init(owner: owner), name: "Byte Primitives"),
            products: ["Byte Primitives"],
            targets: ["Byte Primitives"]
        )
        let facts = Institute.Architecture.Facts(facts: [fact], edges: [])
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: Artifact.today
        )

        #expect(validation.passes)
        #expect(!owner.isCanonical)
        #expect(Institute.Architecture.Owner(coordinate: owner.description) == nil)
        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            _ = try Institute.Architecture.Index.Artifact(
                facts: facts,
                validation: validation
            )
        }
    }

    @Test
    func `round trips a canonical owner coordinate through an artifact`() throws {
        let owner = Institute.Architecture.Owner(
            organization: "swift-atoms",
            name: "swift-byte_primitives.1"
        )
        let fact = Institute.Architecture.Fact(
            owner: owner,
            layer: .atoms,
            concept: .init(identifier: .init(owner: owner), name: "Byte Primitives"),
            products: ["Byte Primitives"],
            targets: ["Byte Primitives"]
        )
        let facts = Institute.Architecture.Facts(facts: [fact], edges: [])
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: Artifact.today
        )
        let artifact = try Institute.Architecture.Index.Artifact(
            facts: facts,
            validation: validation
        )

        #expect(owner.isCanonical)
        #expect(Institute.Architecture.Owner(coordinate: owner.description) == owner)
        try Institute.Architecture.Index.Artifact.verify(
            artifact.rendered,
            facts: facts,
            validation: validation
        )
    }

    @Test
    func `refuses a tampered digest binding`() throws {
        let artifact = try Artifact.fixture()
        let tampered = ArtifactFoundation.replacingOccurrences(
            in: artifact.rendered,
            of: "validation\tvalid",
            with: "validation\tinvalid"
        )

        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            try Artifact.verify(tampered)
        }
    }

    @Test
    func `refuses an incompatible schema`() throws {
        let artifact = try Artifact.fixture()
        let incompatible = ArtifactFoundation.replacingOccurrences(
            in: artifact.rendered,
            of: "version\t1",
            with: "version\t2"
        )

        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            try Artifact.verify(incompatible)
        }
    }

    @Test
    func `refuses a passing report for different derived inputs`() throws {
        let facts = Artifact.inputs()
        let unrelated = Artifact.fact(
            organization: "swift-atoms",
            name: "swift-atom-primitives",
            layer: .atoms,
            products: ["Atom Primitives"]
        )
        let unrelatedFacts = Institute.Architecture.Facts(facts: [unrelated], edges: [])
        let unrelatedValidation = Institute.Architecture.Validator().validate(
            derived: unrelatedFacts,
            today: Artifact.today
        )

        #expect(unrelatedValidation.passes)
        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            _ = try Institute.Architecture.Index.Artifact(
                facts: facts,
                validation: unrelatedValidation
            )
        }
    }

    @Test
    func `refuses recomputed digests with tampered coverage`() throws {
        let artifact = try Artifact.fixture()
        let tampered = Artifact.recomputingDigest(
            ArtifactFoundation.replacingOccurrences(
                in: artifact.rendered,
                of: "measurement\tcomplete\t2/2",
                with: "measurement\tcomplete\t1/1"
            )
        )

        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            try Artifact.verify(tampered)
        }
    }

    @Test
    func `refuses recomputed digests with an entry index mismatch`() throws {
        let artifact = try Artifact.fixture()
        let tampered = Artifact.recomputingDigest(
            ArtifactFoundation.replacingOccurrences(
                in: artifact.rendered,
                of: "products=1",
                with: "products=9"
            )
        )

        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            try Artifact.verify(tampered)
        }
    }

    @Test
    func `refuses recomputed digests with a rewritten edge`() throws {
        let artifact = try Artifact.fixture()
        let tampered = Artifact.recomputingDigest(
            ArtifactFoundation.replacingOccurrences(
                in: artifact.rendered,
                of:
                    "edge\truntime\tswift-compositions/swift-console\tswift-atoms/swift-byte-primitives",
                with:
                    "edge\ttarget\tswift-compositions/swift-console\tswift-atoms/swift-byte-primitives"
            )
        )

        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            try Artifact.verify(tampered)
        }
    }

    @Test
    func `refuses recomputed digests with a removed edge`() throws {
        let artifact = try Artifact.fixture()
        let tampered = Artifact.recomputingDigest(
            ArtifactFoundation.replacingOccurrences(
                in: artifact.rendered,
                of:
                    "\nedge\truntime\tswift-compositions/swift-console\tswift-atoms/swift-byte-primitives",
                with: ""
            )
        )

        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            try Artifact.verify(tampered)
        }
    }

    @Test
    func `refuses recomputed digests with an added edge`() throws {
        let artifact = try Artifact.fixture()
        let tampered = Artifact.recomputingDigest(
            ArtifactFoundation.replacingOccurrences(
                in: artifact.rendered,
                of:
                    "edge\truntime\tswift-compositions/swift-console\tswift-atoms/swift-byte-primitives",
                with:
                    "edge\truntime\tswift-compositions/swift-console\tswift-atoms/swift-byte-primitives\nedge\ttarget\tswift-compositions/swift-console\tswift-atoms/swift-byte-primitives"
            )
        )

        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            try Artifact.verify(tampered)
        }
    }

    @Test
    func `refuses coverage that does not name exactly the indexed owners`() {
        let fact = Artifact.fact(
            organization: "swift-atoms",
            name: "swift-byte-primitives",
            layer: .atoms,
            products: ["Byte Primitives"]
        )
        let unrelated = Institute.Architecture.Owner(
            organization: "swift-compositions",
            name: "swift-console"
        )
        let facts = Institute.Architecture.Facts(
            facts: [fact],
            edges: [],
            coverage: .init(required: [fact.owner], measured: [fact.owner, unrelated])
        )
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: Artifact.today
        )

        #expect(validation.passes)
        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            _ = try Institute.Architecture.Index.Artifact(
                facts: facts,
                validation: validation
            )
        }
    }

    @Test
    func `refuses incomplete measurement instead of encoding a zero product fact`() {
        let measured = Artifact.fact(
            organization: "swift-atoms",
            name: "swift-byte-primitives",
            layer: .atoms,
            products: ["Byte Primitives"]
        )
        let missing = Institute.Architecture.Owner(
            organization: "swift-compositions",
            name: "swift-console"
        )
        let facts = Institute.Architecture.Facts(
            facts: [measured],
            edges: [],
            coverage: .init(required: [measured.owner, missing], measured: [measured.owner])
        )
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: Artifact.today
        )

        #expect(!validation.passes)
        #expect(facts.coverage.unmeasured == [missing])
        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            _ = try Institute.Architecture.Index.Artifact(
                facts: facts,
                validation: validation
            )
        }
    }

    @Test
    func `keeps a measured zero API package distinct from an unmeasured package`() throws {
        let empty = Artifact.fact(
            organization: "swift-atoms",
            name: "swift-internal-only",
            layer: .atoms,
            products: []
        )
        let facts = Institute.Architecture.Facts(facts: [empty], edges: [])
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: Artifact.today
        )
        let artifact = try Institute.Architecture.Index.Artifact(
            facts: facts,
            validation: validation
        )

        #expect(empty.classification == .internalOnly)
        #expect(artifact.rendered.contains("products=0"))
        #expect(artifact.coverage.complete)
    }

    @Test
    func `refuses forbidden fact edges without a caller-supplied graph`() {
        let lower = Artifact.fact(
            organization: "swift-atoms",
            name: "swift-byte-primitives",
            layer: .atoms,
            products: ["Byte Primitives"]
        )
        let higher = Artifact.fact(
            organization: "swift-compositions",
            name: "swift-console",
            layer: .compositions,
            products: ["Console"]
        )
        let facts = Institute.Architecture.Facts(
            facts: [lower, higher],
            edges: [.init(source: lower.owner, destination: higher.owner, kind: .runtime)]
        )
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: Artifact.today
        )

        #expect(!validation.passes)
        #expect(throws: Institute.Architecture.Index.Artifact.Error.self) {
            _ = try Institute.Architecture.Index.Artifact(
                facts: facts,
                validation: validation
            )
        }
    }

    @Test
    func `keeps similarly named concepts distinct`() throws {
        let primitive = Artifact.fact(
            organization: "swift-atoms",
            name: "swift-json-primitives",
            layer: .atoms,
            products: ["JSON Primitives"]
        )
        let standard = Artifact.fact(
            organization: "swift-standards",
            name: "swift-json-standard",
            layer: .standards,
            products: ["JSON Standard"]
        )
        let facts = Institute.Architecture.Facts(facts: [primitive, standard], edges: [])
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: Artifact.today
        )
        let artifact = try Institute.Architecture.Index.Artifact(
            facts: facts,
            validation: validation
        )

        #expect(validation.passes)
        #expect(
            artifact.index.entries.map(\.concept) == [
                .init(owner: primitive.owner),
                .init(owner: standard.owner),
            ]
        )
    }
}

private enum Artifact {
    static let today = Institute.Architecture.Exemption.Expiry.fixture("2026-08-09")

    static func fixture(
        reversed: Swift.Bool = false
    ) throws -> Institute.Architecture.Index.Artifact {
        let facts = inputs(reversed: reversed)
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: today
        )
        return try .init(facts: facts, validation: validation)
    }

    static func verify(_ rendered: Swift.String) throws {
        let facts = inputs()
        let validation = Institute.Architecture.Validator().validate(
            derived: facts,
            today: today
        )
        try Institute.Architecture.Index.Artifact.verify(
            rendered,
            facts: facts,
            validation: validation
        )
    }

    static func inputs(
        reversed: Swift.Bool = false
    ) -> Institute.Architecture.Facts {
        let primitive = fact(
            organization: "swift-atoms",
            name: "swift-byte-primitives",
            layer: .atoms,
            products: ["Byte Primitives"]
        )
        let foundation = fact(
            organization: "swift-compositions",
            name: "swift-console",
            layer: .compositions,
            products: ["Console"]
        )
        let values = reversed ? [foundation, primitive] : [primitive, foundation]
        return Institute.Architecture.Facts(
            facts: values,
            edges: [.init(source: foundation.owner, destination: primitive.owner, kind: .runtime)]
        )
    }

    static func recomputingDigest(_ rendered: Swift.String) -> Swift.String {
        let payload =
            rendered
            .split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst()
            .joined(separator: "\n")
        return "digest\t\(Institute.Architecture.Index.Digest(text: payload))\n\(payload)"
    }

    static func fact(
        organization: Swift.String,
        name: Swift.String,
        layer: Institute.Architecture.Layer,
        products: [Swift.String]
    ) -> Institute.Architecture.Fact {
        let owner = Institute.Architecture.Owner(organization: organization, name: name)
        return .init(
            owner: owner,
            layer: layer,
            concept: .init(identifier: .init(owner: owner), name: name),
            products: products,
            targets: products
        )
    }
}
