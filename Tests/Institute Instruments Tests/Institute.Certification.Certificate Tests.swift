import Foundation
import JSON
import Testing

@testable import Institute_Instruments
@testable import Institute_Model

extension Institute.Certification.Test {
    @Suite struct Certificate {}
}

extension Institute.Certification.Test.Certificate {
    private static let a = Swift.String(repeating: "a", count: 40)
    private static let b = Swift.String(repeating: "b", count: 40)

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
                    revision: .init(a),
                    kind: .package(layer: .primitives)
                )
            ],
            exclusions: []
        )
    }

    private static func policy(
        admissible: [Institute.Certification.Exception.Reason] = [.notApplicable]
    ) throws -> Institute.Certification.Policy {
        try .init(platforms: [.linux], quality: [], admissible: admissible)
    }

    private static func coverage() throws -> [Institute.Certification.Closure.Coverage] {
        [try .init(consumer: key("swift-primitives/swift-color"), proofs: [])]
    }

    private static func control() throws -> Institute.Certification.Control {
        try .init(
            certifier: .init(b),
            toolchain: "Swift 6.4",
            policy: nil,
            runtimeReceipts: []
        )
    }

    private static func obligation(
        _ kind: Institute.Certification.Obligation.Kind,
        _ platform: Institute.Certification.Platform
    ) -> Institute.Certification.Obligation {
        .init(key: key("swift-primitives/swift-color"), kind: kind, platform: platform)
    }

    @Test
    func `all obligations met is certified`() throws {
        let certificate = try Institute.Certification.Certificate(
            snapshot: Self.snapshot(),
            control: Self.control(),
            policy: Self.policy(),
            obligations: [Self.obligation(.build, .linux), Self.obligation(.test, .linux)],
            accounts: [
                .init(obligation: Self.obligation(.build, .linux), outcome: .met(evidence: "d1")),
                .init(obligation: Self.obligation(.test, .linux), outcome: .met(evidence: "d2")),
            ],
            exceptions: [],
            closure: try Self.coverage(),
            coherenceReceipts: []
        )
        #expect(certificate.verdict == .certified)
    }

    @Test
    func `an uncovered obligation is unmeasured, never green`() throws {
        let certificate = try Institute.Certification.Certificate(
            snapshot: Self.snapshot(),
            control: Self.control(),
            policy: Self.policy(),
            obligations: [Self.obligation(.build, .linux), Self.obligation(.test, .linux)],
            accounts: [
                .init(obligation: Self.obligation(.build, .linux), outcome: .met(evidence: "d1"))
            ],
            exceptions: [],
            closure: try Self.coverage(),
            coherenceReceipts: []
        )
        #expect(certificate.verdict == .unmeasured)
    }

    @Test
    func `a measured failure dominates unmeasured`() throws {
        let certificate = try Institute.Certification.Certificate(
            snapshot: Self.snapshot(),
            control: Self.control(),
            policy: Self.policy(),
            obligations: [Self.obligation(.build, .linux), Self.obligation(.test, .linux)],
            accounts: [
                .init(
                    obligation: Self.obligation(.build, .linux),
                    outcome: .failed(diagnostic: "swift-color: error: x")
                )
            ],
            exceptions: [],
            closure: try Self.coverage(),
            coherenceReceipts: []
        )
        #expect(certificate.verdict == .failed)
    }

    @Test
    func `a policy-admitted exception completes coverage`() throws {
        let certificate = try Institute.Certification.Certificate(
            snapshot: Self.snapshot(),
            control: Self.control(),
            policy: Self.policy(admissible: [.notApplicable, .knownDefect]),
            obligations: [Self.obligation(.build, .linux), Self.obligation(.test, .windows)],
            accounts: [
                .init(obligation: Self.obligation(.build, .linux), outcome: .met(evidence: "d1"))
            ],
            exceptions: [
                .init(
                    obligation: Self.obligation(.test, .windows),
                    reason: .knownDefect,
                    authority: "swift-institute/.github#600"
                )
            ],
            closure: try Self.coverage(),
            coherenceReceipts: []
        )
        #expect(certificate.verdict == .certified)
    }

    @Test
    func `a known defect is refused unless the policy admits it`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Certificate(
                snapshot: Self.snapshot(),
                control: Self.control(),
                policy: Self.policy(),
                obligations: [Self.obligation(.test, .windows)],
                accounts: [],
                exceptions: [
                    .init(
                        obligation: Self.obligation(.test, .windows),
                        reason: .knownDefect,
                        authority: "swift-institute/.github#600"
                    )
                ],
                closure: try Self.coverage(),
                coherenceReceipts: []
            )
        }
    }

    @Test
    func `a package member without closure coverage is unmeasured`() throws {
        let certificate = try Institute.Certification.Certificate(
            snapshot: Self.snapshot(),
            control: Self.control(),
            policy: Self.policy(),
            obligations: [Self.obligation(.build, .linux)],
            accounts: [
                .init(obligation: Self.obligation(.build, .linux), outcome: .met(evidence: "d1"))
            ],
            exceptions: [],
            closure: [],
            coherenceReceipts: []
        )
        #expect(certificate.verdict == .unmeasured)
    }

    @Test
    func `double coverage of one obligation is refused`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Certificate(
                snapshot: Self.snapshot(),
                control: Self.control(),
                policy: Self.policy(),
                obligations: [Self.obligation(.build, .linux)],
                accounts: [
                    .init(
                        obligation: Self.obligation(.build, .linux),
                        outcome: .met(evidence: "d1")
                    )
                ],
                exceptions: [
                    .init(
                        obligation: Self.obligation(.build, .linux),
                        reason: .notApplicable,
                        authority: "swift-institute/.github#600"
                    )
                ],
                closure: try Self.coverage(),
                coherenceReceipts: []
            )
        }
    }

    @Test
    func `an account for unrequested work is refused`() throws {
        #expect(throws: Institute.Error.self) {
            _ = try Institute.Certification.Certificate(
                snapshot: Self.snapshot(),
                control: Self.control(),
                policy: Self.policy(),
                obligations: [Self.obligation(.build, .linux)],
                accounts: [
                    .init(
                        obligation: Self.obligation(.test, .macos),
                        outcome: .met(evidence: "d1")
                    )
                ],
                exceptions: [],
                closure: try Self.coverage(),
                coherenceReceipts: []
            )
        }
    }

    @Test
    func `a certificate round-trips and a corrupt verdict is refused`() throws {
        let certificate = try Institute.Certification.Certificate(
            snapshot: Self.snapshot(),
            control: Self.control(),
            policy: Self.policy(),
            obligations: [Self.obligation(.build, .linux)],
            accounts: [
                .init(obligation: Self.obligation(.build, .linux), outcome: .met(evidence: "d1"))
            ],
            exceptions: [],
            closure: try Self.coverage(),
            coherenceReceipts: ["c1"]
        )
        let decoded = try Institute.Certification.Certificate(
            jsonString: certificate.canonical
        )
        #expect(decoded == certificate)
        #expect(decoded.digest == certificate.digest)

        let corrupt = certificate.canonical.replacingOccurrences(
            of: "\"verdict\":\"certified\"",
            with: "\"verdict\":\"failed\""
        )
        #expect(throws: JSON.Error.self) {
            _ = try Institute.Certification.Certificate(jsonString: corrupt)
        }
    }

    @Test
    func `status is current only at exactly the certified revisions`() throws {
        let certificate = try Institute.Certification.Certificate(
            snapshot: Self.snapshot(),
            control: Self.control(),
            policy: Self.policy(),
            obligations: [Self.obligation(.build, .linux)],
            accounts: [
                .init(obligation: Self.obligation(.build, .linux), outcome: .met(evidence: "d1"))
            ],
            exceptions: [],
            closure: try Self.coverage(),
            coherenceReceipts: []
        )
        let member = Self.key("swift-primitives/swift-color")
        #expect(
            try certificate.status(against: [member: .init(Self.a)], control: Self.control())
                == .current
        )
        #expect(
            try certificate.status(against: [member: .init(Self.b)], control: Self.control())
                == .superseded(moved: [member], controlMoved: false)
        )
        // An unobserved member is moved: unknown is never current.
        #expect(
            try certificate.status(against: [:], control: Self.control())
                == .superseded(moved: [member], controlMoved: false)
        )
        // Control movement supersedes exactly as head movement does.
        let movedControl = try Institute.Certification.Control(
            certifier: .init(Self.a),
            toolchain: "Swift 6.5",
            policy: nil,
            runtimeReceipts: []
        )
        #expect(
            try certificate.status(against: [member: .init(Self.a)], control: movedControl)
                == .superseded(moved: [], controlMoved: true)
        )
    }
}
