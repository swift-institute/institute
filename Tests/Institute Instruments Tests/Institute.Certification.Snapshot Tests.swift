import JSON
import Testing

@testable import Institute_Instruments
@testable import Institute_Model

extension Institute.Certification {
    @Suite
    struct Test {
        @Suite struct Unit {}
    }
}

extension Institute.Certification.Test.Unit {
    private static func key(_ identity: Swift.String) -> Institute.Repository.Key {
        guard let key = Institute.Repository.Key(identity: identity) else {
            fatalError("test fixture identity must be valid: \(identity)")
        }
        return key
    }

    private static func member(
        _ identity: Swift.String,
        _ sha: Swift.String,
        kind: Institute.Certification.Member.Kind = .package(layer: .primitives)
    ) throws -> Institute.Certification.Member {
        try .init(key: key(identity), revision: .init(sha), kind: kind)
    }

    private static let a = Swift.String(repeating: "a", count: 40)
    private static let b = Swift.String(repeating: "b", count: 40)
    private static let c = Swift.String(repeating: "c", count: 40)

    @Test
    func `a full lowercase forty-digit revision constructs`() throws {
        let revision = try Institute.Certification.Revision(Self.a)
        #expect(revision.sha == Self.a)
    }

    @Test
    func `an abbreviated revision is refused`() {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Revision("abc1234")
        }
    }

    @Test
    func `an uppercase revision is refused`() {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Revision(
                Swift.String(repeating: "A", count: 40)
            )
        }
    }

    @Test
    func `a non-hexadecimal revision of full length is refused`() {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Revision(
                Swift.String(repeating: "g", count: 40)
            )
        }
    }

    @Test
    func `an empty snapshot cannot exist`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Snapshot(
                inventoryCommit: .init(Self.a),
                inventoryBlob: Self.b,
                members: [],
                exclusions: []
            )
        }
    }

    @Test
    func `a duplicate member identity is refused`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Snapshot(
                inventoryCommit: .init(Self.a),
                inventoryBlob: Self.b,
                members: [
                    Self.member("swift-primitives/swift-color", Self.a),
                    Self.member("swift-primitives/swift-color", Self.b),
                ],
                exclusions: []
            )
        }
    }

    @Test
    func `an identity cannot be both admitted and excluded`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Snapshot(
                inventoryCommit: .init(Self.a),
                inventoryBlob: Self.b,
                members: [Self.member("swift-primitives/swift-color", Self.a)],
                exclusions: [
                    .init(
                        key: Self.key("swift-primitives/swift-color"),
                        reason: .archived
                    )
                ]
            )
        }
    }

    @Test
    func `construction order does not change the digest`() throws {
        let first = try Institute.Certification.Snapshot(
            inventoryCommit: .init(Self.a),
            inventoryBlob: Self.b,
            members: [
                Self.member("swift-primitives/swift-color", Self.a),
                Self.member("swift-foundations/swift-html", Self.b),
                Self.member(
                    "swift-institute/institute",
                    Self.c,
                    kind: .controlPlane
                ),
            ],
            exclusions: []
        )
        let second = try Institute.Certification.Snapshot(
            inventoryCommit: .init(Self.a),
            inventoryBlob: Self.b,
            members: [
                Self.member(
                    "swift-institute/institute",
                    Self.c,
                    kind: .controlPlane
                ),
                Self.member("swift-foundations/swift-html", Self.b),
                Self.member("swift-primitives/swift-color", Self.a),
            ],
            exclusions: []
        )
        #expect(first == second)
        #expect(first.digest == second.digest)
    }

    @Test
    func `a moved revision changes the digest`() throws {
        func snapshot(_ sha: Swift.String) throws -> Institute.Certification.Snapshot {
            try .init(
                inventoryCommit: .init(Self.a),
                inventoryBlob: Self.b,
                members: [Self.member("swift-primitives/swift-color", sha)],
                exclusions: []
            )
        }
        #expect(try snapshot(Self.a).digest != snapshot(Self.b).digest)
    }

    @Test
    func `a snapshot round-trips through its canonical serialization`() throws {
        let snapshot = try Institute.Certification.Snapshot(
            inventoryCommit: .init(Self.a),
            inventoryBlob: Self.b,
            members: [
                Self.member("swift-primitives/swift-color", Self.a),
                Self.member(
                    "swift-institute/.github",
                    Self.c,
                    kind: .controlPlane
                ),
            ],
            exclusions: [
                .init(
                    key: Self.key("swift-primitives/swift-legacy"),
                    reason: .archived
                )
            ]
        )
        let decoded = try Institute.Certification.Snapshot(
            jsonString: snapshot.canonical
        )
        #expect(decoded == snapshot)
        #expect(decoded.digest == snapshot.digest)
    }

    @Test
    func `member lookup by identity finds the admitted revision`() throws {
        let snapshot = try Institute.Certification.Snapshot(
            inventoryCommit: .init(Self.a),
            inventoryBlob: Self.b,
            members: [Self.member("swift-primitives/swift-color", Self.c)],
            exclusions: []
        )
        #expect(
            snapshot[Self.key("swift-primitives/swift-color")]?.revision.sha == Self.c
        )
        #expect(snapshot[Self.key("swift-primitives/swift-absent")] == nil)
    }

    @Test
    func `member kinds serialize distinguishably`() throws {
        let package = try Self.member("swift-primitives/swift-color", Self.a)
        let central = try Self.member(
            "swift-institute/institute",
            Self.b,
            kind: .controlPlane
        )
        #expect(
            try Institute.Certification.Member(json: package.json) == package
        )
        #expect(
            try Institute.Certification.Member(json: central.json) == central
        )
        #expect(package.kind != central.kind)
    }
}
