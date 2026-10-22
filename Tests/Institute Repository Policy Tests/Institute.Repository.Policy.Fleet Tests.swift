import Institute_CI_Model
import Institute_Model
import Institute_Repository_Policy
import JSON
import Testing

@Suite
struct `Institute repository policy fleet` {
    static func document(compositions layer: Swift.String = "L4") -> Swift.String {
        """
        {
          "schemaVersion": 1,
          "organizations": [
            {"name": "swift-atoms", "layer": "L1", "status": "active"},
            {"name": "swift-molecules", "layer": "L2", "status": "active"},
            {"name": "swift-standards", "layer": "L3", "status": "active"},
            {"name": "swift-compositions", "layer": "\(layer)", "status": "active"},
            {"name": "swift-institute", "layer": "control", "status": "active"}
          ]
        }
        """
    }

    static func fleet(_ text: Swift.String) throws -> Institute.Repository.Policy.Fleet {
        try JSON.parse(text).decode(Institute.Repository.Policy.Fleet.self)
    }

    @Test
    func `four layer organizations validate`() throws {
        try Self.fleet(Self.document()).validate()
    }

    @Test
    func `each layer selects its lint bundle`() throws {
        let fleet = try Self.fleet(Self.document())
        #expect(try fleet.configuration(for: "swift-atoms/swift-ratio").lintBundle == "primitives")
        #expect(try fleet.configuration(for: "swift-molecules/swift-pool").lintBundle == "primitives")
        #expect(try fleet.configuration(for: "swift-standards/swift-rfc-6570").lintBundle == "standards")
        #expect(try fleet.configuration(for: "swift-compositions/swift-webpage").lintBundle == "institute")
        #expect(try fleet.configuration(for: "swift-institute/institute").lintBundle == "institute")
    }

    @Test
    func `embedded selection is mapped by repository identity`() throws {
        let fleet = try Self.fleet(Self.document())

        #expect(try fleet.configuration(for: "swift-atoms/swift-ratio").embedded == .package)
        for (repository, target) in [
            "swift-atoms/swift-fixed": "Fixed Standard Library Integration",
            "swift-atoms/swift-io": "IO",
            "swift-atoms/swift-iterator": "Iterator",
            "swift-atoms/swift-pool": "Pool Bounded",
            "swift-atoms/swift-renderer": "Renderer",
            "swift-atoms/swift-sample": "Sample",
            "swift-atoms/swift-system": "System Standard Library Integration",
            "swift-atoms/swift-time": "Time",
            "swift-molecules/swift-builder": "Builder Standard Library Integration",
            "swift-molecules/swift-range": "Range Standard Library Integration",
            "swift-molecules/swift-stack": "Stack Standard Library Integration",
            "swift-molecules/swift-token": "Token Standard Library Integration",
            "swift-molecules/swift-tree": "Tree Standard Library Integration",
        ] {
            #expect(try fleet.configuration(for: repository).embedded == .target(target))
        }
    }

    @Test
    func `hosted only identities are not admitted to embedded`() throws {
        let fleet = try Self.fleet(Self.document())
        for repository in [
            "swift-molecules/swift-foundation-extensions",
            "swift-atoms/swift-argument",
            "swift-atoms/swift-geometry",
            "swift-atoms/swift-linear",
            "swift-atoms/swift-spatial",
            "swift-atoms/swift-anamorphism",
            "swift-atoms/swift-apomorphism",
            "swift-atoms/swift-catamorphism",
            "swift-atoms/swift-chronomorphism",
            "swift-atoms/swift-futumorphism",
            "swift-atoms/swift-histomorphism",
            "swift-atoms/swift-hylomorphism",
            "swift-atoms/swift-paramorphism",
            "swift-atoms/swift-zygomorphism",
            "swift-molecules/swift-test",
        ] {
            #expect(try fleet.configuration(for: repository).embedded == .absent)
        }
    }

    @Test
    func `organization membership does not admit a new identity`() throws {
        let fleet = try Self.fleet(Self.document())
        #expect(try fleet.configuration(for: "swift-atoms/swift-new").embedded == .absent)
        #expect(try fleet.configuration(for: "swift-molecules/swift-new").embedded == .absent)
        #expect(try fleet.configuration(for: "swift-molecules/swift-pool").embedded == .absent)
    }

    @Test
    func `an unknown layer is rejected`() throws {
        let fleet = try Self.fleet(Self.document(compositions: "L5"))
        #expect(throws: Institute.Repository.Policy.Fleet.Error.invalidLayer("L5")) {
            try fleet.validate()
        }
    }
}
