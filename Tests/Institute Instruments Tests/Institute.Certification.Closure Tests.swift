import JSON
import SPM_Standard
import Testing

@testable import Institute_Instruments
@testable import Institute_Model

extension Institute.Certification.Test {
    @Suite struct Closure {}
}

extension Institute.Certification.Test.Closure {
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
                ),
                .init(
                    key: key("swift-foundations/swift-sockets"),
                    revision: .init(b),
                    kind: .package(layer: .foundations)
                ),
            ],
            exclusions: [
                .init(key: key("swift-primitives/swift-legacy"), reason: .archived)
            ]
        )
    }

    private static func dependency(
        _ location: Swift.String,
        _ state: Package.Resolution.Dependency.State
    ) -> Package.Resolution.Dependency {
        .init(
            reference: .init(
                identity: .init("x"),
                kind: .remoteSourceControl,
                location: location,
                name: "x"
            ),
            state: state,
            subpath: "x"
        )
    }

    private static func checkout(
        _ revision: Swift.String
    ) -> Package.Resolution.Dependency.State {
        .sourceControlCheckout(.init(revision: revision, pin: .branch("main")))
    }

    @Test
    func `an exact managed checkout of a member passes`() throws {
        let proofs = Institute.Certification.Closure.proofs(
            consumer: Self.key("swift-foundations/swift-sockets"),
            resolution: .init(dependencies: [
                Self.dependency(
                    "https://github.com/swift-primitives/swift-color.git",
                    Self.checkout(Self.a)
                )
            ]),
            snapshot: try Self.snapshot()
        )
        #expect(proofs.count == 1)
        #expect(proofs[0].passes)
        #expect(proofs[0].verdict == .exact(Self.key("swift-primitives/swift-color")))
    }

    @Test
    func `a governed identity outside the population fails closed`() throws {
        // The swift-tls class: swift-foundations is governed, swift-tls is
        // not an admitted member (institute-application#212).
        let proofs = Institute.Certification.Closure.proofs(
            consumer: Self.key("swift-foundations/swift-sockets"),
            resolution: .init(dependencies: [
                Self.dependency(
                    "https://github.com/swift-foundations/swift-tls.git",
                    Self.checkout(Self.a)
                )
            ]),
            snapshot: try Self.snapshot()
        )
        #expect(proofs.count == 1)
        #expect(!proofs[0].passes)
        #expect(
            proofs[0].verdict == .ungoverned(Self.key("swift-foundations/swift-tls"))
        )
    }

    @Test
    func `revision skew against the snapshot member fails`() throws {
        let proofs = Institute.Certification.Closure.proofs(
            consumer: Self.key("swift-foundations/swift-sockets"),
            resolution: .init(dependencies: [
                Self.dependency(
                    "https://github.com/swift-primitives/swift-color.git",
                    Self.checkout(Self.b)
                )
            ]),
            snapshot: try Self.snapshot()
        )
        #expect(!proofs[0].passes)
        guard case .revisionSkew(let key, let resolved, let member) = proofs[0].verdict
        else {
            Issue.record("expected revisionSkew, got \(proofs[0].verdict)")
            return
        }
        #expect(key == Self.key("swift-primitives/swift-color"))
        #expect(resolved == Self.b)
        #expect(member == Self.a)
    }

    @Test
    func `an edge to a typed-excluded member is recorded and passes`() throws {
        let proofs = Institute.Certification.Closure.proofs(
            consumer: Self.key("swift-foundations/swift-sockets"),
            resolution: .init(dependencies: [
                Self.dependency(
                    "https://github.com/swift-primitives/swift-legacy.git",
                    Self.checkout(Self.a)
                )
            ]),
            snapshot: try Self.snapshot()
        )
        #expect(proofs[0].passes)
        #expect(
            proofs[0].verdict
                == .excludedMember(Self.key("swift-primitives/swift-legacy"))
        )
    }

    @Test
    func `an external-organization edge produces no proof`() throws {
        let proofs = Institute.Certification.Closure.proofs(
            consumer: Self.key("swift-foundations/swift-sockets"),
            resolution: .init(dependencies: [
                Self.dependency(
                    "https://github.com/apple/swift-syntax.git",
                    Self.checkout(Self.a)
                )
            ]),
            snapshot: try Self.snapshot()
        )
        #expect(proofs.isEmpty)
    }

    @Test
    func `a local path is an escape unless the mode accepts it`() throws {
        let resolution = Package.Resolution(dependencies: [
            Self.dependency(
                "https://github.com/swift-primitives/swift-color.git",
                .fileSystem(path: "/tmp/anywhere")
            )
        ])
        let strict = Institute.Certification.Closure.proofs(
            consumer: Self.key("swift-foundations/swift-sockets"),
            resolution: resolution,
            snapshot: try Self.snapshot()
        )
        #expect(!strict[0].passes)
        let composed = Institute.Certification.Closure.proofs(
            consumer: Self.key("swift-foundations/swift-sockets"),
            resolution: resolution,
            snapshot: try Self.snapshot(),
            accepting: [.localPath]
        )
        #expect(composed[0].passes)
    }

    @Test
    func `a failing proof fails the certificate`() throws {
        let obligation = Institute.Certification.Obligation(
            key: Self.key("swift-primitives/swift-color"),
            kind: .build,
            platform: .linux
        )
        let certificate = try Institute.Certification.Certificate(
            snapshot: Self.snapshot(),
            control: .init(
                certifier: .init(Self.b),
                toolchain: "Swift 6.4",
                policy: nil,
                runtimeReceipts: []
            ),
            obligations: [obligation],
            accounts: [.init(obligation: obligation, outcome: .met(evidence: "d1"))],
            exceptions: [],
            closure: [
                .init(
                    consumer: Self.key("swift-foundations/swift-sockets"),
                    location: "https://github.com/swift-foundations/swift-tls.git",
                    verdict: .ungoverned(Self.key("swift-foundations/swift-tls"))
                )
            ],
            coherenceReceipts: []
        )
        #expect(certificate.verdict == .failed)
        let decoded = try Institute.Certification.Certificate(
            jsonString: certificate.canonical
        )
        #expect(decoded == certificate)
    }
}
