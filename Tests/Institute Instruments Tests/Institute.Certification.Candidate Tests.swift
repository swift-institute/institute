import JSON
import Testing

@testable import Institute_Instruments
@testable import Institute_Model

extension Institute.Certification.Test {
    @Suite struct Candidate {}
}

extension Institute.Certification.Test.Candidate {
    private static let a = Swift.String(repeating: "a", count: 40)
    private static let b = Swift.String(repeating: "b", count: 40)
    private static let c = Swift.String(repeating: "c", count: 40)

    private static func key(_ identity: Swift.String) -> Institute.Repository.Key {
        guard let key = Institute.Repository.Key(identity: identity) else {
            fatalError("test fixture identity must be valid: \(identity)")
        }
        return key
    }

    private static func snapshot() throws -> Institute.Certification.Snapshot {
        try .init(
            inventoryCommit: .init(a),
            inventoryBlob: b,
            members: [
                .init(
                    key: key("swift-primitives/swift-color"),
                    revision: .init(c),
                    kind: .package(layer: .primitives)
                ),
                .init(
                    key: key("swift-foundations/swift-html"),
                    revision: .init(a),
                    kind: .package(layer: .foundations)
                ),
            ],
            exclusions: []
        )
    }

    @Test
    func `a candidate binds affected heads to admitted members`() throws {
        let candidate = try Institute.Certification.Candidate(
            campaign: "tools-version-6.4",
            snapshot: Self.snapshot(),
            heads: [
                .init(
                    key: Self.key("swift-primitives/swift-color"),
                    pullRequest: 12,
                    revision: .init(Self.c),
                    patchDigest: "p1"
                )
            ]
        )
        #expect(candidate.heads.count == 1)
        let decoded = try Institute.Certification.Candidate(
            jsonString: candidate.canonical
        )
        #expect(decoded == candidate)
        #expect(decoded.digest == candidate.digest)
    }

    @Test
    func `a head for a non-member is refused`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Candidate(
                campaign: "tools-version-6.4",
                snapshot: Self.snapshot(),
                heads: [
                    .init(
                        key: Self.key("swift-primitives/swift-absent"),
                        pullRequest: 12,
                        revision: .init(Self.c),
                        patchDigest: "p1"
                    )
                ]
            )
        }
    }

    @Test
    func `a head disagreeing with its snapshot member is refused`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Candidate(
                campaign: "tools-version-6.4",
                snapshot: Self.snapshot(),
                heads: [
                    .init(
                        key: Self.key("swift-primitives/swift-color"),
                        pullRequest: 12,
                        revision: .init(Self.b),
                        patchDigest: "p1"
                    )
                ]
            )
        }
    }

    @Test
    func `an anonymous campaign is refused`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Candidate(
                campaign: "",
                snapshot: Self.snapshot(),
                heads: []
            )
        }
    }

    @Test
    func `duplicate heads for one member are refused`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Candidate(
                campaign: "tools-version-6.4",
                snapshot: Self.snapshot(),
                heads: [
                    .init(
                        key: Self.key("swift-primitives/swift-color"),
                        pullRequest: 12,
                        revision: .init(Self.c),
                        patchDigest: "p1"
                    ),
                    .init(
                        key: Self.key("swift-primitives/swift-color"),
                        pullRequest: 13,
                        revision: .init(Self.c),
                        patchDigest: "p2"
                    ),
                ]
            )
        }
    }
}
