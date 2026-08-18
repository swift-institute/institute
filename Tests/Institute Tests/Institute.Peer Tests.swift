import File_System
import Foundation
import JSON
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

extension Institute.Peer {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Peer.Test.Unit {
    @Test
    func `a peer record round-trips through its exact key set`() throws {
        let decoded = try Institute.Peer(
            jsonString: #"{"inventory": ".github/inventory.json", "name": "rule-institute"}"#
        )

        #expect(decoded == .init(name: "rule-institute", inventory: ".github/inventory.json"))
    }

    @Test
    func `a registry names its peers`() throws {
        let registry = try Institute.Peer.Registry(
            jsonString: """
                {
                  "peers": [
                    {"inventory": ".github/inventory.json", "name": "rule-institute"}
                  ],
                  "version": 1
                }
                """
        ).validated()

        #expect(registry.peers.map(\.name) == ["rule-institute"])
    }

    @Test
    func `an absent registry file is an empty registry, never an error`() throws {
        let temporary =
            FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }

        let registry = try Institute.Peer.Registry.load(
            at: File.Directory(validating: temporary.path)
        )

        #expect(registry.peers.isEmpty)
    }
}

extension Institute.Peer.Test.`Edge Case` {
    @Test
    func `an extra key is a decode error, not a silent pass-through`() {
        #expect(throws: JSON.Error.self) {
            _ = try Institute.Peer(
                jsonString: #"{"inventory": "a", "name": "b", "root": "/machine/path"}"#
            )
        }
    }

    @Test
    func `a duplicate peer name fails validation`() {
        let registry = Institute.Peer.Registry(
            version: 1,
            peers: [
                .init(name: "rule-institute", inventory: "a.json"),
                .init(name: "rule-institute", inventory: "b.json"),
            ]
        )

        #expect(throws: Institute.Error.self) {
            _ = try registry.validated()
        }
    }

    @Test(arguments: ["rule/institute", ".", "..", ""])
    func `a peer name that is not a single component fails validation`(name: Swift.String) {
        let registry = Institute.Peer.Registry(
            version: 1,
            peers: [.init(name: name, inventory: "inventory.json")]
        )

        #expect(throws: Institute.Error.self) {
            _ = try registry.validated()
        }
    }

    @Test(arguments: ["../inventory.json", "a/../b.json", "", "/etc/inventory.json"])
    func `a traversing or absolute inventory path fails validation`(path: Swift.String) {
        let registry = Institute.Peer.Registry(
            version: 1,
            peers: [.init(name: "rule-institute", inventory: path)]
        )

        #expect(throws: Institute.Error.self) {
            _ = try registry.validated()
        }
    }

    @Test
    func `an unsupported registry version fails validation`() {
        let registry = Institute.Peer.Registry(version: 2, peers: [])

        #expect(throws: Institute.Error.self) {
            _ = try registry.validated()
        }
    }
}
