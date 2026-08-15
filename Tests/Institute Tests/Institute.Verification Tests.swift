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

extension Institute.Verification {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Redaction {}
        @Suite struct Check {}
    }
}

extension Institute.Verification.Test {
    static let coordinate = Institute.Repository.Key(identity: "swift-primitives/swift-example")!
    static let head = "1111111111111111111111111111111111111111"

    static func operation(
        _ kind: Institute.Verification.Operation.Kind,
        outcome: Institute.Verification.Operation.Outcome = .success,
        compileEvidence: Swift.String? = nil,
        findings: [Swift.String] = []
    ) -> Institute.Verification.Operation.Result {
        .init(
            operation: kind,
            arguments: [],
            startedAt: "2026-08-04T00:00:00Z",
            endedAt: "2026-08-04T00:00:01Z",
            durationSeconds: 1,
            exitCode: 0,
            provenance: .cached,
            outcome: outcome,
            compileEvidence: compileEvidence,
            findings: findings
        )
    }

    static func environment(swift: Swift.String = "6.4") -> Institute.Verification.Environment {
        .init(
            swift: swift,
            xcode: "26.0",
            sdk: "26.0",
            os: "macos",
            architecture: "arm64",
            runnerImage: nil
        )
    }

    /// A run whose every real-tool closure is a deterministic stub — no
    /// process spawn, no real checkout — so unit tests exercise
    /// ``Run/run()``'s own refusal and sealing logic in isolation, exactly
    /// the ``Institute/Coherence/Run`` and ``Institute/Conversion/Seal``
    /// pattern.
    static func run(
        claimedHead: Swift.String = head,
        observedHead: Swift.String? = nil,
        isDirty: Swift.Bool = false,
        requestedOperations: [Institute.Verification.Operation.Kind] = [.build, .test],
        requiredOperations: [Institute.Verification.Operation.Kind] = [.build, .test],
        buildResult: Institute.Verification.Operation.Result? = nil,
        testResult: Institute.Verification.Operation.Result? = nil,
        environmentSwift: Swift.String = "6.4",
        inventoryDigest: Institute.Verification.Inventory.Digest = .measured(
            Swift.String(repeating: "a", count: 64)
        ),
        workspaceRevision: Swift.String = "2222222222222222222222222222222222222222",
        policyRevision: Swift.String = "policy-1"
    ) -> Institute.Verification.Run {
        .init(
            packagePath: "/tmp/subject",
            claimedHead: claimedHead,
            coordinate: coordinate,
            visibility: .private,
            defaultBranch: "main",
            layer: .primitives,
            inventoryDigest: inventoryDigest,
            workspaceRevision: workspaceRevision,
            policyRevision: policyRevision,
            requestedOperations: requestedOperations,
            requiredOperations: requiredOperations,
            tools: .init(
                head: { _ throws(Institute.Error) in observedHead ?? claimedHead },
                dirty: { _ throws(Institute.Error) in isDirty },
                build: { _, _, _, _ in buildResult ?? Institute.Verification.Test.operation(.build)
                },
                test: { _, _, _, _ in testResult ?? Institute.Verification.Test.operation(.test) },
                nestedTests: { _, _, _, _ in [] },
                lint: { _ in Institute.Verification.Test.operation(.lint) },
                environment: { Institute.Verification.Test.environment(swift: environmentSwift) },
                now: { "2026-08-04T00:00:00Z" }
            )
        )
    }
}

extension Institute.Verification.Test.Unit {
    @Test
    func `A run whose subject matches its claim and whose operations succeed is verified`() throws {
        let receipt = try Institute.Verification.Test.run().run()
        #expect(receipt.verdict == .verified)
        #expect(receipt.operations.count == 2)
        // An explicit closure, not `\.satisfied` — the Swift Testing
        // `#expect` macro's expansion mis-infers a bare key-path-as-predicate
        // argument to `allSatisfy` as throwing on this toolchain, tripping
        // "call can throw, but it is not marked with 'try'" with no `try`
        // anywhere in the source. A closure sidesteps the macro's expansion
        // issue without changing what is asserted.
        #expect(receipt.requiredGates.allSatisfy { $0.satisfied })
    }

    @Test
    func `Two runs over the same semantic input produce identical canonical JSON`() throws {
        let first = try Institute.Verification.Test.run().run()
        let second = try Institute.Verification.Test.run().run()
        #expect(first.canonical == second.canonical)
    }

    @Test
    func `Changing the claimed subject head changes the canonical digest`() throws {
        let first = try Institute.Verification.Test.run().run()
        let second = try Institute.Verification.Test.run(
            claimedHead: "3333333333333333333333333333333333333333",
            observedHead: "3333333333333333333333333333333333333333"
        ).run()
        #expect(first.canonical != second.canonical)
    }

    @Test
    func `Changing one operation result changes the canonical digest`() throws {
        let first = try Institute.Verification.Test.run().run()
        let second = try Institute.Verification.Test.run(
            buildResult: Institute.Verification.Test.operation(.build, outcome: .failure)
        ).run()
        #expect(first.canonical != second.canonical)
    }

    @Test
    func `Changing the observed toolchain changes the canonical digest`() throws {
        let first = try Institute.Verification.Test.run().run()
        let second = try Institute.Verification.Test.run(environmentSwift: "6.5").run()
        #expect(first.canonical != second.canonical)
    }

    @Test
    func `Changing the inventory digest changes the canonical digest`() throws {
        let first = try Institute.Verification.Test.run().run()
        let second = try Institute.Verification.Test.run(
            inventoryDigest: .measured(Swift.String(repeating: "b", count: 64))
        ).run()
        #expect(first.canonical != second.canonical)
    }

    @Test
    func `A build failure seals as an unverified receipt rather than refusing`() throws {
        let receipt = try Institute.Verification.Test.run(
            buildResult: Institute.Verification.Test.operation(.build, outcome: .failure)
        ).run()
        #expect(receipt.verdict.fails)
    }
}

extension Institute.Verification.Test.`Edge Case` {
    @Test
    func `Zero requested operations refuses to seal`() {
        #expect(throws: Institute.Verification.Error.noOperationExecuted) {
            try Institute.Verification.Test.run(requestedOperations: [], requiredOperations: [])
                .run()
        }
    }

    @Test
    func `A required operation that was never requested refuses to seal`() {
        #expect(throws: Institute.Verification.Error.requiredOperationMissing(.lint)) {
            try Institute.Verification.Test.run(
                requestedOperations: [.build],
                requiredOperations: [.build, .lint]
            ).run()
        }
    }

    @Test
    func `A required operation that came back unmeasured refuses to seal`() {
        #expect(
            throws: Institute.Verification.Error.requiredOperationNotExecuted(.build)
        ) {
            try Institute.Verification.Test.run(
                buildResult: Institute.Verification.Test.operation(
                    .build,
                    outcome: .unmeasured(reason: "synthetic")
                )
            ).run()
        }
    }

    @Test
    func `A claimed head that does not match the observed head refuses to seal`() {
        #expect(
            throws: Institute.Verification.Error.headMismatch(
                claimed: Institute.Verification.Test.head,
                observed: "4444444444444444444444444444444444444444"
            )
        ) {
            try Institute.Verification.Test.run(
                observedHead: "4444444444444444444444444444444444444444"
            )
            .run()
        }
    }

    @Test
    func `A dirty subject checkout refuses to seal`() {
        #expect(throws: Institute.Verification.Error.dirtySubject("/tmp/subject")) {
            try Institute.Verification.Test.run(isDirty: true).run()
        }
    }

    @Test
    func `A secret-shaped diagnostic refuses to seal`() {
        #expect(throws: (Institute.Verification.Error).self) {
            try Institute.Verification.Test.run(
                buildResult: Institute.Verification.Test.operation(
                    .build,
                    outcome: .failure,
                    compileEvidence: "error: token ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa leaked"
                )
            ).run()
        }
    }

    @Test
    func `An absolute machine path in a finding refuses to seal`() {
        let run = Institute.Verification.Run(
            packagePath: "/tmp/subject",
            claimedHead: Institute.Verification.Test.head,
            coordinate: Institute.Verification.Test.coordinate,
            visibility: .private,
            defaultBranch: "main",
            layer: .primitives,
            inventoryDigest: .measured(Swift.String(repeating: "a", count: 64)),
            workspaceRevision: "2222222222222222222222222222222222222222",
            policyRevision: "policy-1",
            requestedOperations: [.lint],
            requiredOperations: [.lint],
            tools: .init(
                head: { _ throws(Institute.Error) in Institute.Verification.Test.head },
                dirty: { _ throws(Institute.Error) in false },
                build: { _, _, _, _ in Institute.Verification.Test.operation(.build) },
                test: { _, _, _, _ in Institute.Verification.Test.operation(.test) },
                nestedTests: { _, _, _, _ in [] },
                lint: { _ in
                    Institute.Verification.Test.operation(
                        .lint,
                        findings: [
                            "/Users/coen/Developer/coenttb/swift-primitives/Secret.swift:1:1: note"
                        ]
                    )
                },
                environment: { Institute.Verification.Test.environment() },
                now: { "2026-08-04T00:00:00Z" }
            )
        )
        #expect(throws: (Institute.Verification.Error).self) {
            try run.run()
        }
    }
}

extension Institute.Verification.Test.Unit {
    /// The same receipt with a different inventory digest — `Receipt` is a
    /// value type with no `with`-style member, and three tests here need
    /// exactly this one substitution.
    static func reseal(
        _ receipt: Institute.Verification.Receipt,
        digest: Institute.Verification.Inventory.Digest
    ) -> Institute.Verification.Receipt {
        .init(
            subject: receipt.subject,
            inventoryDigest: digest,
            layer: receipt.layer,
            workspaceRevision: receipt.workspaceRevision,
            policyRevision: receipt.policyRevision,
            environment: receipt.environment,
            requestedOperations: receipt.requestedOperations,
            operations: receipt.operations,
            platform: receipt.platform,
            requiredGates: receipt.requiredGates,
            verdict: receipt.verdict
        )
    }

    @Test
    func `An unmeasured inventory digest without a cause cannot be constructed`() {
        #expect(throws: Institute.Verification.Inventory.Digest.Error.unmeasuredWithoutCause) {
            try Institute.Verification.Inventory.Digest(token: "unmeasured", cause: nil)
        }
        #expect(throws: Institute.Verification.Inventory.Digest.Error.unmeasuredWithoutCause) {
            try Institute.Verification.Inventory.Digest(token: "unmeasured", cause: "")
        }
    }

    @Test
    func `A measured inventory digest is 64 lowercase hex digits and carries no cause`() throws {
        let digest = Swift.String(repeating: "a", count: 64)
        #expect(
            try Institute.Verification.Inventory.Digest(token: digest, cause: nil)
                == .measured(digest)
        )
        #expect(throws: Institute.Verification.Inventory.Digest.Error.measuredWithCause) {
            try Institute.Verification.Inventory.Digest(token: digest, cause: "because")
        }
        #expect(throws: Institute.Verification.Inventory.Digest.Error.notLowercaseHex64) {
            try Institute.Verification.Inventory.Digest(token: "deadbeef", cause: nil)
        }
        #expect(throws: Institute.Verification.Inventory.Digest.Error.notLowercaseHex64) {
            try Institute.Verification.Inventory.Digest(
                token: Swift.String(repeating: "A", count: 64),
                cause: nil
            )
        }
    }

    @Test
    func `A receipt carries the cause only when nothing was measured`() throws {
        let measured = Institute.Verification.Test.Check.verifiedReceipt()
        // A measured receipt's canonical bytes are unchanged by the
        // existence of the cause field — the digest of every receipt sealed
        // before this schema addition still matches.
        #expect(!measured.canonical.contains("inventoryDigestCause"))

        let unmeasured = Self.reseal(
            measured,
            digest: .unmeasured(cause: "no cross-organization credential")
        )
        #expect(unmeasured.canonical.contains("inventoryDigestCause"))
        #expect(unmeasured.canonical.contains("no cross-organization credential"))

        let roundTripped = try Institute.Verification.Receipt(json: unmeasured.json)
        #expect(roundTripped == unmeasured)
    }

    @Test
    func `A receipt claiming unmeasured without a cause does not parse`() {
        let measured = Institute.Verification.Test.Check.verifiedReceipt()
        let text = measured.canonical.replacing(
            measured.inventoryDigest.token,
            with: "unmeasured"
        )
        #expect(throws: JSON.Error.self) {
            try Institute.Verification.Receipt(json: JSON.parse(text))
        }
    }
}

extension Institute.Verification.Test.Unit {
    @Test
    func `Compile evidence under the subject root is relativized, not refused`() throws {
        let root = "/Users/runner/work/Example/Example"
        let result = Institute.Verification.Operation.Result(
            operation: .build,
            arguments: [],
            startedAt: "2026-08-07T00:00:00Z",
            endedAt: "2026-08-07T00:00:01Z",
            durationSeconds: 1,
            exitCode: 1,
            provenance: .cached,
            outcome: .failure,
            compileEvidence: "\(root)/Sources/A.swift:1:1: error: cannot find 'x' in scope",
            findings: ["\(root)/Sources/B.swift:2:2: warning: rule fired"]
        ).relative(to: root)

        #expect(result.compileEvidence == "Sources/A.swift:1:1: error: cannot find \'x\' in scope")
        #expect(result.findings == ["Sources/B.swift:2:2: warning: rule fired"])
        #expect(Institute.Verification.Redaction.diagnose(result.compileEvidence ?? "") == nil)
    }
}

extension Institute.Verification.Test.Redaction {
    @Test
    func `A GitHub PAT shape is recognised`() {
        #expect(
            Institute.Verification.Redaction.diagnose("ghp_aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
                != nil
        )
    }

    @Test
    func `A PEM header is recognised`() {
        #expect(Institute.Verification.Redaction.diagnose("-----BEGIN PRIVATE KEY-----") != nil)
    }

    @Test
    func `An absolute machine path is recognised`() {
        #expect(
            Institute.Verification.Redaction.diagnose("/Users/coen/Developer/secret") != nil
        )
    }

    @Test
    func `A lint finding under the subject root becomes sealable once relativized`() {
        let root = "/home/runner/work/Example/Example"
        let finding = "\(root)/Sources/Example/Example.swift:12:5: warning: rule fired"
        #expect(Institute.Verification.Redaction.diagnose(finding) != nil)
        let relative = Institute.Verification.Redaction.relative(finding, to: root)
        #expect(relative == "Sources/Example/Example.swift:12:5: warning: rule fired")
        #expect(Institute.Verification.Redaction.diagnose(relative) == nil)
    }

    @Test
    func `A trailing slash on the subject root does not survive relativization`() {
        #expect(
            Institute.Verification.Redaction.relative(
                "/home/runner/work/Example/Package.swift",
                to: "/home/runner/work/Example/"
            ) == "Package.swift"
        )
    }

    @Test
    func `An absolute path outside the subject root is still refused`() {
        let text = "/home/runner/work/Example/Sources/A.swift refers to /Users/coen/toolchain"
        #expect(
            Institute.Verification.Redaction.diagnose(
                Institute.Verification.Redaction.relative(text, to: "/home/runner/work/Example")
            ) != nil
        )
    }

    @Test
    func `Every lint refusal reason is sealable`() {
        let refusals: [Institute.Verification.Run.Refusal] = [
            .unresolvableTarget(.filesystem),
            .unresolvableConfiguration(.configuration),
            .unavailableInstallation(.process),
            .unsealableMeasurementReason,
        ]
        for refusal in refusals {
            #expect(Institute.Verification.Redaction.diagnose(refusal.description) == nil)
        }
    }

    @Test
    func `An ordinary compiler diagnostic is not flagged`() {
        #expect(
            Institute.Verification.Redaction.diagnose(
                "Sources/Example/Example.swift:12:5: error: cannot find 'foo' in scope"
            ) == nil
        )
    }
}

extension Institute.Verification.Test.Check {
    static func verifiedReceipt() -> Institute.Verification.Receipt {
        .init(
            subject: .init(
                coordinate: Institute.Verification.Test.coordinate,
                visibility: .private,
                defaultBranch: "main",
                claimedHead: Institute.Verification.Test.head,
                observedHead: Institute.Verification.Test.head,
                dirty: false
            ),
            inventoryDigest: .measured(Swift.String(repeating: "a", count: 64)),
            layer: .primitives,
            workspaceRevision: "2222222222222222222222222222222222222222",
            policyRevision: "policy-1",
            environment: Institute.Verification.Test.environment(),
            requestedOperations: [.build, .test],
            operations: [
                Institute.Verification.Test.operation(.build),
                Institute.Verification.Test.operation(.test),
            ],
            platform: .init(declared: ["macOS"], measured: "macos"),
            requiredGates: [
                .init(name: "build", satisfied: true),
                .init(name: "test", satisfied: true),
            ],
            verdict: .verified
        )
    }

    @Test
    func `A consistent verified receipt has no diagnostics`() {
        #expect(Institute.Verification.Check.diagnostics(for: Self.verifiedReceipt()).isEmpty)
    }

    @Test
    func `A verified receipt over a dirty subject is flagged inconsistent`() {
        var receipt = Self.verifiedReceipt()
        receipt = Institute.Verification.Receipt(
            subject: .init(
                coordinate: receipt.subject.coordinate,
                visibility: receipt.subject.visibility,
                defaultBranch: receipt.subject.defaultBranch,
                claimedHead: receipt.subject.claimedHead,
                observedHead: receipt.subject.observedHead,
                dirty: true
            ),
            inventoryDigest: receipt.inventoryDigest,
            layer: receipt.layer,
            workspaceRevision: receipt.workspaceRevision,
            policyRevision: receipt.policyRevision,
            environment: receipt.environment,
            requestedOperations: receipt.requestedOperations,
            operations: receipt.operations,
            platform: receipt.platform,
            requiredGates: receipt.requiredGates,
            verdict: receipt.verdict
        )
        #expect(!Institute.Verification.Check.diagnostics(for: receipt).isEmpty)
    }

    @Test
    func `A verified receipt whose required gate is unsatisfied is flagged inconsistent`() {
        let base = Self.verifiedReceipt()
        let receipt = Institute.Verification.Receipt(
            subject: base.subject,
            inventoryDigest: base.inventoryDigest,
            layer: base.layer,
            workspaceRevision: base.workspaceRevision,
            policyRevision: base.policyRevision,
            environment: base.environment,
            requestedOperations: base.requestedOperations,
            operations: base.operations,
            platform: base.platform,
            requiredGates: [.init(name: "build", satisfied: false)],
            verdict: .verified
        )
        #expect(!Institute.Verification.Check.diagnostics(for: receipt).isEmpty)
    }

    @Test
    func `An unverified receipt round-trips through JSON with an identical digest`() throws {
        let receipt = Self.verifiedReceipt()
        let decoded = try Institute.Verification.Receipt(jsonString: receipt.canonical)
        #expect(decoded == receipt)
        #expect(decoded.canonical == receipt.canonical)
    }
}
