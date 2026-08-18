import File_System
import Foundation
import JSON
import Testing

@testable import Institute_Instruments
@testable import Institute_Model

extension Institute.Certification.Test {
    @Suite struct Execution {}
}

extension Institute.Certification.Test.Execution {
    private static let a = Swift.String(repeating: "a", count: 40)
    private static let b = Swift.String(repeating: "b", count: 40)

    private static func key(_ identity: Swift.String) -> Institute.Repository.Key {
        guard let key = Institute.Repository.Key(identity: identity) else {
            fatalError("test fixture identity must be valid: \(identity)")
        }
        return key
    }

    private static func repository() -> Institute.Repository {
        .init(
            name: "swift-color",
            url: "https://github.com/swift-primitives/swift-color.git",
            organization: "swift-primitives",
            layer: .primitives
        )
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

    /// A fixture with the repository materialized as a plain directory —
    /// `head` and `run` are injected, so no Git or SwiftPM executes.
    private static func fixture(
        materializedHead: Swift.String?,
        outcome: Institute.Certification.Account.Outcome
    ) throws -> Institute.Certification.Execution {
        let temporary = FileManager.default.temporaryDirectory
            .appendingPathComponent("certification-execution-\(UUID().uuidString)")
        let checkout = temporary.appendingPathComponent("swift-institute/institute")
        let materialization = temporary.appendingPathComponent(
            "swift-primitives/swift-color"
        )
        try FileManager.default.createDirectory(
            at: checkout,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: materialization,
            withIntermediateDirectories: true
        )
        return try .init(
            root: Institute.Root(checkout: File.Directory(validating: checkout.path)),
            configuration: .init(
                version: 1,
                scope: "test",
                swift: "6.3.3",
                xcode: "26",
                repositories: [Self.repository()]
            ),
            platform: .macos,
            head: { _, repository throws(Institute.Error) in
                guard let materializedHead else {
                    throw .repository(
                        "\(repository.organization)/\(repository.name): unreadable"
                    )
                }
                return try .init(materializedHead)
            },
            run: { _, _ in outcome }
        )
    }

    @Test
    func `an obligation on another platform is unmeasured, never green`() throws {
        let execution = try Self.fixture(
            materializedHead: Self.a,
            outcome: .met(evidence: "exit:0")
        )
        let accounts = execution.accounts(
            for: [
                .init(
                    key: Self.key("swift-primitives/swift-color"),
                    kind: .build,
                    platform: .windows
                )
            ],
            in: try Self.snapshot()
        )
        #expect(accounts.count == 1)
        guard case .unmeasured(let reason) = accounts[0].outcome else {
            Issue.record("expected unmeasured, got \(accounts[0].outcome)")
            return
        }
        #expect(reason.contains("windows"))
    }

    @Test
    func `a matching materialization executes and records the outcome`() throws {
        let execution = try Self.fixture(
            materializedHead: Self.a,
            outcome: .met(evidence: "exit:0")
        )
        let accounts = execution.accounts(
            for: [
                .init(
                    key: Self.key("swift-primitives/swift-color"),
                    kind: .test,
                    platform: .macos
                )
            ],
            in: try Self.snapshot()
        )
        #expect(accounts[0].outcome == .met(evidence: "exit:0"))
    }

    @Test
    func `a wrong-revision materialization fails rather than executing`() throws {
        let execution = try Self.fixture(
            materializedHead: Self.b,
            outcome: .met(evidence: "exit:0")
        )
        let accounts = execution.accounts(
            for: [
                .init(
                    key: Self.key("swift-primitives/swift-color"),
                    kind: .build,
                    platform: .macos
                )
            ],
            in: try Self.snapshot()
        )
        guard case .failed(let diagnostic) = accounts[0].outcome else {
            Issue.record("expected failed, got \(accounts[0].outcome)")
            return
        }
        #expect(diagnostic.contains(Self.b))
        #expect(diagnostic.contains(Self.a))
    }

    @Test
    func `an unreadable head is unmeasured`() throws {
        let execution = try Self.fixture(
            materializedHead: nil,
            outcome: .met(evidence: "exit:0")
        )
        let accounts = execution.accounts(
            for: [
                .init(
                    key: Self.key("swift-primitives/swift-color"),
                    kind: .build,
                    platform: .macos
                )
            ],
            in: try Self.snapshot()
        )
        guard case .unmeasured = accounts[0].outcome else {
            Issue.record("expected unmeasured, got \(accounts[0].outcome)")
            return
        }
    }

    @Test
    func `a non-member obligation fails attributably`() throws {
        let execution = try Self.fixture(
            materializedHead: Self.a,
            outcome: .met(evidence: "exit:0")
        )
        let accounts = execution.accounts(
            for: [
                .init(
                    key: Self.key("swift-primitives/swift-absent"),
                    kind: .build,
                    platform: .macos
                )
            ],
            in: try Self.snapshot()
        )
        guard case .failed(let diagnostic) = accounts[0].outcome else {
            Issue.record("expected failed, got \(accounts[0].outcome)")
            return
        }
        #expect(diagnostic.contains("swift-primitives/swift-absent"))
    }
}
