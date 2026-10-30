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
    func `an unknown layer is rejected`() throws {
        let fleet = try Self.fleet(Self.document(compositions: "L5"))
        #expect(throws: Institute.Repository.Policy.Fleet.Error.invalidLayer("L5")) {
            try fleet.validate()
        }
    }
}
