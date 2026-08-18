import File_System
import Foundation
import JSON
import Testing

@testable import Institute_Instruments
@testable import Institute_Model

extension Institute.Certification.Test {
    @Suite struct Derivation {}
}

extension Institute.Certification.Test.Derivation {
    private static let a = Swift.String(repeating: "a", count: 40)
    private static let b = Swift.String(repeating: "b", count: 40)
    private static let c = Swift.String(repeating: "c", count: 40)

    private static func key(_ identity: Swift.String) -> Institute.Repository.Key {
        guard let key = Institute.Repository.Key(identity: identity) else {
            fatalError("test fixture identity must be valid: \(identity)")
        }
        return key
    }

    private static func repository(
        _ organization: Swift.String,
        _ name: Swift.String,
        layer: Institute.Layer = .primitives
    ) -> Institute.Repository {
        .init(
            name: name,
            url: "https://github.com/\(organization)/\(name).git",
            organization: organization,
            layer: layer
        )
    }

    private static func fixture(
        repositories: [Institute.Repository],
        heads: [Swift.String: Swift.String]
    ) throws -> Institute.Certification.Derivation {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("certification-derivation-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: temporary,
            withIntermediateDirectories: true
        )
        return try .init(
            root: Institute.Root(checkout: File.Directory(validating: temporary.path)),
            configuration: .init(
                version: 1,
                scope: "test",
                swift: "6.3.3",
                xcode: "26",
                repositories: repositories
            ),
            head: { _, repository throws(Institute.Error) in
                guard
                    let sha = heads["\(repository.organization)/\(repository.name)"]
                else {
                    throw .repository(
                        "\(repository.organization)/\(repository.name): "
                            + "head of main is unreadable"
                    )
                }
                return try .init(sha)
            }
        )
    }

    @Test
    func `every inventory member lands at its exact revision`() throws {
        let derivation = try Self.fixture(
            repositories: [
                Self.repository("swift-primitives", "swift-color"),
                Self.repository("swift-foundations", "swift-html", layer: .foundations),
            ],
            heads: [
                "swift-primitives/swift-color": Self.a,
                "swift-foundations/swift-html": Self.b,
            ]
        )
        let snapshot = try derivation.snapshot(
            inventoryCommit: .init(Self.c),
            inventoryBlob: Self.a,
            centrals: [Self.key("swift-institute/institute"): .init(Self.c)],
            exclusions: []
        )
        #expect(snapshot.members.count == 3)
        #expect(
            snapshot[Self.key("swift-primitives/swift-color")]?.revision.sha == Self.a
        )
        #expect(
            snapshot[Self.key("swift-institute/institute")]?.kind == .controlPlane
        )
    }

    @Test
    func `an unreadable unexcluded member fails the derivation`() throws {
        let derivation = try Self.fixture(
            repositories: [
                Self.repository("swift-primitives", "swift-color"),
                Self.repository("swift-primitives", "swift-broken"),
            ],
            heads: ["swift-primitives/swift-color": Self.a]
        )
        #expect(throws: Institute.Error.self) {
            _ = try derivation.snapshot(
                inventoryCommit: .init(Self.c),
                inventoryBlob: Self.a,
                centrals: [:],
                exclusions: []
            )
        }
    }

    @Test
    func `an explicit typed exclusion covers an unreadable member`() throws {
        let derivation = try Self.fixture(
            repositories: [
                Self.repository("swift-primitives", "swift-color"),
                Self.repository("swift-primitives", "swift-broken"),
            ],
            heads: ["swift-primitives/swift-color": Self.a]
        )
        let snapshot = try derivation.snapshot(
            inventoryCommit: .init(Self.c),
            inventoryBlob: Self.a,
            centrals: [:],
            exclusions: [
                .init(
                    key: Self.key("swift-primitives/swift-broken"),
                    reason: .inaccessible
                )
            ]
        )
        #expect(snapshot.members.count == 1)
        #expect(snapshot.exclusions.count == 1)
    }

    @Test
    func `an abbreviated head fails rather than being padded or accepted`() throws {
        let derivation = try Self.fixture(
            repositories: [Self.repository("swift-primitives", "swift-color")],
            heads: ["swift-primitives/swift-color": "abc1234"]
        )
        #expect(throws: Institute.Error.self) {
            _ = try derivation.snapshot(
                inventoryCommit: .init(Self.c),
                inventoryBlob: Self.a,
                centrals: [:],
                exclusions: []
            )
        }
    }
}
