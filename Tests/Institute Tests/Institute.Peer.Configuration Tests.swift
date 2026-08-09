import JSON
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

extension Institute.Peer.Configuration {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}

        static let peer = Institute.Peer(
            name: "rule-institute",
            inventory: ".github/inventory.json"
        )

        static func repository(
            name: Swift.String,
            organization: Swift.String
        ) -> Institute.Peer.Repository {
            .init(
                name: name,
                url: "https://github.com/\(organization)/\(name).git",
                organization: organization
            )
        }
    }
}

extension Institute.Peer.Configuration.Test.Unit {
    @Test
    func `a peer inventory mirrors the workspace record shape minus layer`() throws {
        let configuration = try Institute.Peer.Configuration(
            jsonString: """
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
        ).validated(for: Institute.Peer.Configuration.Test.peer)

        #expect(configuration.ecosystem == "rule-institute")
        #expect(configuration.repositories.map(\.name) == ["burgerlijk-wetboek-boek-2"])
    }
}

extension Institute.Peer.Configuration.Test.`Edge Case` {
    @Test
    func `an ecosystem mismatch fails validation`() {
        let configuration = Institute.Peer.Configuration(
            version: 1,
            ecosystem: "another-institute",
            repositories: []
        )

        #expect(throws: Institute.Error.self) {
            _ = try configuration.validated(for: Institute.Peer.Configuration.Test.peer)
        }
    }

    @Test
    func `a URL owner that is not the declared organization fails validation`() {
        let configuration = Institute.Peer.Configuration(
            version: 1,
            ecosystem: "rule-institute",
            repositories: [
                .init(
                    name: "burgerlijk-wetboek-boek-2",
                    url: "https://github.com/another-org/burgerlijk-wetboek-boek-2.git",
                    organization: "swift-nl-wetgever"
                )
            ]
        )

        #expect(throws: Institute.Error.self) {
            _ = try configuration.validated(for: Institute.Peer.Configuration.Test.peer)
        }
    }

    @Test
    func `a duplicate repository name fails validation`() {
        let repository = Institute.Peer.Configuration.Test.repository(
            name: "rule-law",
            organization: "rule-law"
        )
        let configuration = Institute.Peer.Configuration(
            version: 1,
            ecosystem: "rule-institute",
            repositories: [repository, repository]
        )

        #expect(throws: Institute.Error.self) {
            _ = try configuration.validated(for: Institute.Peer.Configuration.Test.peer)
        }
    }

    @Test
    func `a non-canonical URL fails validation`() {
        let configuration = Institute.Peer.Configuration(
            version: 1,
            ecosystem: "rule-institute",
            repositories: [
                .init(
                    name: "rule-law",
                    url: "https://example.com/rule-law/rule-law.git",
                    organization: "rule-law"
                )
            ]
        )

        #expect(throws: Institute.Error.self) {
            _ = try configuration.validated(for: Institute.Peer.Configuration.Test.peer)
        }
    }
}
