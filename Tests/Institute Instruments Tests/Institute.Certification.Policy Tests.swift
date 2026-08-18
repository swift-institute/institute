import JSON
import Testing

@testable import Institute_Instruments
@testable import Institute_Model

extension Institute.Certification.Test {
    @Suite struct Policy {}
}

extension Institute.Certification.Test.Policy {
    private static let a = Swift.String(repeating: "a", count: 40)
    private static let b = Swift.String(repeating: "b", count: 40)

    private static func key(_ identity: Swift.String) -> Institute.Repository.Key {
        guard let key = Institute.Repository.Key(identity: identity) else {
            fatalError("test fixture identity must be valid: \(identity)")
        }
        return key
    }

    @Test
    func `an empty platform set is refused`() {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Policy(platforms: [])
        }
    }

    @Test
    func `a duplicate platform is refused`() {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Policy(platforms: [.linux, .linux])
        }
    }

    @Test
    func `obligations derive per package member and platform, deterministically`() throws {
        let snapshot = try Institute.Certification.Snapshot(
            inventoryCommit: .init(Self.a),
            inventoryBlob: Self.b,
            members: [
                .init(
                    key: Self.key("swift-primitives/swift-color"),
                    revision: .init(Self.a),
                    kind: .package(layer: .primitives)
                ),
                .init(
                    key: Self.key("swift-institute/institute"),
                    revision: .init(Self.b),
                    kind: .controlPlane
                ),
            ],
            exclusions: []
        )
        let policy = try Institute.Certification.Policy(platforms: [.macos, .linux])
        let derived = Institute.Certification.Obligation.derive(
            from: snapshot,
            policy: policy
        )
        // One package member × (build, test) × 2 platforms; the
        // control-plane member contributes none.
        #expect(derived.count == 4)
        #expect(derived.allSatisfy { $0.key.identity == "swift-primitives/swift-color" })
        #expect(
            derived
                == Institute.Certification.Obligation.derive(from: snapshot, policy: policy)
        )
    }
}
