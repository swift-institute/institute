import Testing

@testable import Institute_Conversion
@testable import Institute_Dependency
@testable import Institute_Development
@testable import Institute_Doctor
@testable import Institute_Instruments
@testable import Institute_Inventory
@testable import Institute_Lint
@testable import Institute_Model
@testable import Institute_Pages

extension Institute.Peer.Report {
    @Suite
    struct Test {
        @Suite struct Unit {}

        static let peer = Institute.Peer(
            name: "rule-institute",
            inventory: ".github/inventory.json"
        )
    }
}

extension Institute.Peer.Report.Test.Unit {
    @Test
    func `an unmaterialized peer reports the opt-in`() {
        let report = Institute.Peer.Report(
            peer: Institute.Peer.Report.Test.peer,
            presence: .absent
        )

        #expect(report.description == "peer rule-institute: not materialized (opt-in)")
    }

    @Test
    func `a declared peer lists entry-relative paths, never absolute ones`() {
        let report = Institute.Peer.Report(
            peer: Institute.Peer.Report.Test.peer,
            presence: .declared(
                .init(
                    version: 1,
                    ecosystem: "rule-institute",
                    repositories: [
                        .init(
                            name: "burgerlijk-wetboek-boek-2",
                            url:
                                "https://github.com/swift-nl-wetgever/burgerlijk-wetboek-boek-2.git",
                            organization: "swift-nl-wetgever"
                        )
                    ]
                )
            )
        )

        #expect(
            report.description == """
                peer rule-institute: 1 repositories (name → organization → path)
                  burgerlijk-wetboek-boek-2 → swift-nl-wetgever → \
                rule-institute/swift-nl-wetgever/burgerlijk-wetboek-boek-2
                """
        )
    }

    @Test
    func `a peer without an inventory names the declared path`() {
        let report = Institute.Peer.Report(
            peer: Institute.Peer.Report.Test.peer,
            presence: .missing(".github/inventory.json")
        )

        #expect(
            report.description
                == "peer rule-institute: materialized without an inventory at .github/inventory.json"
        )
    }
}
