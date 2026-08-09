import Testing

@testable import Institute_Model
@testable import Institute_Inventory
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Lint
@testable import Institute_Pages
@testable import Institute_Doctor
@testable import Institute_Conversion
@testable import Institute_Instruments

extension Institute.Doctor.Peer {
    @Suite
    struct Test {
        @Suite struct Integration {}

        static let peer = Institute.Peer(
            name: "rule-institute",
            inventory: ".github/inventory.json"
        )

        static let repository = Institute.Peer.Repository(
            name: "burgerlijk-wetboek-boek-2",
            url: "https://github.com/swift-nl-wetgever/burgerlijk-wetboek-boek-2.git",
            organization: "swift-nl-wetgever"
        )

        static let inventory = """
            {
              "ecosystem": "rule-institute",
              "repositories": [
                {
                  "name": "burgerlijk-wetboek-boek-2",
                  "organization": "swift-nl-wetgever",
                  "url": "https://github.com/swift-nl-wetgever/burgerlijk-wetboek-boek-2.git"
                }
              ],
              "version": 1
            }
            """
    }
}

extension Institute.Doctor.Peer.Test.Integration {
    private func outcome(
        of report: Institute.Doctor.Report
    ) throws -> Institute.Doctor.Outcome {
        try #require(report.outcomes.first { $0.check == "peer-checkout" })
    }

    @Test
    func `an empty registry measures an empty population as ok`() async throws {
        let fixture = try Institute.Peer.Fixture()
        defer { fixture.remove() }

        let report = await fixture.doctor(peers: []).run(access: .contributor)

        #expect(try outcome(of: report).result == .ok(population: 0))
    }

    @Test
    func `an unmaterialized peer is a fact, not a finding`() async throws {
        let fixture = try Institute.Peer.Fixture()
        defer { fixture.remove() }

        let report = await fixture.doctor(peers: [Institute.Doctor.Peer.Test.peer])
            .run(access: .contributor)

        let outcome = try outcome(of: report)
        #expect(outcome.result == .ok(population: 1))
        #expect(outcome.findings.isEmpty)
    }

    @Test
    func `a materialized peer without an inventory warns`() async throws {
        let fixture = try Institute.Peer.Fixture()
        defer { fixture.remove() }
        try fixture.materializeRoot(of: Institute.Doctor.Peer.Test.peer)

        let report = await fixture.doctor(peers: [Institute.Doctor.Peer.Test.peer])
            .run(access: .contributor)

        let outcome = try outcome(of: report)
        #expect(outcome.result == .finding(severity: .warning, population: 1))
        #expect(outcome.findings.map(\.severity) == [.warning])
    }

    @Test
    func `an undecodable inventory is an error`() async throws {
        let fixture = try Institute.Peer.Fixture()
        defer { fixture.remove() }
        try fixture.materializeRoot(of: Institute.Doctor.Peer.Test.peer)
        try fixture.write(
            "not json",
            at: ".github/inventory.json",
            for: Institute.Doctor.Peer.Test.peer
        )

        let report = await fixture.doctor(peers: [Institute.Doctor.Peer.Test.peer])
            .run(access: .contributor)

        #expect(try outcome(of: report).result == .finding(severity: .error, population: 1))
    }

    @Test
    func `an inventory declaring another ecosystem is an error`() async throws {
        let fixture = try Institute.Peer.Fixture()
        defer { fixture.remove() }
        try fixture.materializeRoot(of: Institute.Doctor.Peer.Test.peer)
        try fixture.write(
            #"{"ecosystem": "another-institute", "repositories": [], "version": 1}"#,
            at: ".github/inventory.json",
            for: Institute.Doctor.Peer.Test.peer
        )

        let report = await fixture.doctor(peers: [Institute.Doctor.Peer.Test.peer])
            .run(access: .contributor)

        #expect(try outcome(of: report).result == .finding(severity: .error, population: 1))
    }

    @Test
    func `a declared repository materialized at its location measures canonical`() async throws {
        let fixture = try Institute.Peer.Fixture()
        defer { fixture.remove() }
        try fixture.materializeRoot(of: Institute.Doctor.Peer.Test.peer)
        try fixture.write(
            Institute.Doctor.Peer.Test.inventory,
            at: ".github/inventory.json",
            for: Institute.Doctor.Peer.Test.peer
        )
        try fixture.materialize(
            Institute.Doctor.Peer.Test.repository,
            in: Institute.Doctor.Peer.Test.peer
        )

        let report = await fixture.doctor(peers: [Institute.Doctor.Peer.Test.peer])
            .run(access: .contributor)

        let outcome = try outcome(of: report)
        #expect(outcome.result == .ok(population: 2))
        #expect(outcome.findings.isEmpty)
    }

    @Test
    func `a declared repository not materialized is a fact, not a finding`() async throws {
        let fixture = try Institute.Peer.Fixture()
        defer { fixture.remove() }
        try fixture.materializeRoot(of: Institute.Doctor.Peer.Test.peer)
        try fixture.write(
            Institute.Doctor.Peer.Test.inventory,
            at: ".github/inventory.json",
            for: Institute.Doctor.Peer.Test.peer
        )

        let report = await fixture.doctor(peers: [Institute.Doctor.Peer.Test.peer])
            .run(access: .contributor)

        let outcome = try outcome(of: report)
        #expect(outcome.result == .ok(population: 2))
        #expect(outcome.findings.isEmpty)
    }
}
