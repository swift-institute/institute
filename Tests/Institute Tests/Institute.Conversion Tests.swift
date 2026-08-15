import Foundation
import JSON
import Tagged_Primitives
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

extension Institute.Conversion {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
    }
}

extension Institute.Conversion.Test {
    static func coordinate(_ identity: Swift.String) -> Institute.Repository.Key {
        Institute.Repository.Key(identity: identity)!
    }

    static func repository(
        _ identity: Swift.String,
        layer: Institute.Layer = .primitives
    ) -> Institute.Repository {
        let key = coordinate(identity)
        return .init(
            name: key.name.underlying,
            url: key.url,
            organization: key.owner.underlying,
            layer: layer
        )
    }

    static func instrument(
        pageInventoryDigest: Swift.String = "digest-0"
    )
        -> Institute.Conversion.Instrument
    {
        .init(
            workspaceCommit: "0000000000000000000000000000000000000",
            workspaceJsonBlob: "1111111111111111111111111111111111111",
            selection: "policy",
            pageInventoryDigest: pageInventoryDigest
        )
    }

    static func page(
        _ identity: Swift.String,
        kind: Institute.Pages.Kind = .readme,
        path: Swift.String = "README.md",
        pre: Swift.String,
        post: Swift.String? = nil,
        disposition: Institute.Conversion.Page.Disposition = .unmeasured
    ) -> Institute.Conversion.Page {
        .init(
            coordinate: coordinate(identity),
            kind: kind,
            path: path,
            preConversionBlob: pre,
            postConversionBlob: post,
            disposition: disposition
        )
    }

    static func cohortEntry(
        _ identity: Swift.String,
        layer: Institute.Layer = .primitives,
        preConversionHead: Swift.String = "head-1"
    ) -> Institute.Conversion.Repository {
        let key = coordinate(identity)
        return .init(
            coordinate: key,
            layer: layer,
            cloneURL: key.url,
            preConversionHead: preConversionHead
        )
    }
}

extension Institute.Conversion.Test.Unit {
    @Test
    func `A receipt's canonical form is deterministic and round-trips through JSON`() throws {
        let receipt = Institute.Conversion.Receipt(
            instrument: Institute.Conversion.Test.instrument(),
            cohort: [
                Institute.Conversion.Test.cohortEntry("swift-primitives/swift-example-two"),
                Institute.Conversion.Test.cohortEntry("swift-primitives/swift-example-one"),
            ],
            pages: [
                Institute.Conversion.Test.page(
                    "swift-primitives/swift-example-two",
                    pre: "blob-two"
                ),
                Institute.Conversion.Test.page(
                    "swift-primitives/swift-example-one",
                    pre: "blob-one"
                ),
            ],
            driftChecks: []
        )

        let first = receipt.canonical
        let second = receipt.canonical
        #expect(first == second)

        let decoded = try Institute.Conversion.Receipt(jsonString: first)
        #expect(decoded == receipt)

        // Sorted by canonical coordinate regardless of construction order.
        #expect(
            receipt.cohort.map(\.coordinate.identity) == [
                "swift-primitives/swift-example-one",
                "swift-primitives/swift-example-two",
            ]
        )
        #expect(
            receipt.pages.map(\.coordinate.identity) == [
                "swift-primitives/swift-example-one",
                "swift-primitives/swift-example-two",
            ]
        )
    }

    @Test
    func
        `evaluationCohort excludes a digest-equal pair and an unconverted page, keeping the one differing pair`()
    {
        let receipt = Institute.Conversion.Receipt(
            instrument: Institute.Conversion.Test.instrument(),
            cohort: [
                Institute.Conversion.Test.cohortEntry("swift-primitives/equal"),
                Institute.Conversion.Test.cohortEntry("swift-primitives/differing"),
                Institute.Conversion.Test.cohortEntry("swift-primitives/unconverted"),
            ],
            pages: [
                Institute.Conversion.Test.page(
                    "swift-primitives/equal",
                    pre: "same-blob",
                    post: "same-blob"
                ),
                Institute.Conversion.Test.page(
                    "swift-primitives/differing",
                    pre: "old-blob",
                    post: "new-blob"
                ),
                Institute.Conversion.Test.page(
                    "swift-primitives/unconverted",
                    pre: "old-blob",
                    post: nil
                ),
            ],
            driftChecks: []
        )

        let cohort = receipt.evaluationCohort
        #expect(cohort.count == 3)
        let nonExcluded = cohort.filter { !$0.excluded }
        #expect(nonExcluded.count == 1)
        #expect(nonExcluded.first?.coordinate.identity == "swift-primitives/differing")
    }

    @Test
    func `An unknown disposition string fails deserialization rather than decoding to a default`() {
        #expect(throws: (any Swift.Error).self) {
            _ = try Institute.Conversion.Page.Disposition(jsonString: "\"deleted\"")
        }
    }

    @Test
    func
        `A seal run over a fixture with one non-canonical repository throws rather than sealing a partial cohort`()
        async throws
    {
        let repositories = [
            Institute.Conversion.Test.repository("swift-primitives/swift-example-one"),
            Institute.Conversion.Test.repository("swift-primitives/swift-example-two"),
        ]
        let fixture = try Institute.Doctor.Fixture(repositories: repositories)
        defer { fixture.remove() }
        // Only the first repository is materialized; the second is absent
        // — the exact shape `isFullyCanonical` exists to catch.
        try fixture.materialize(repositories[0].name)

        let seal = Institute.Conversion.Seal(root: fixture.root, selection: fixture.selection)

        await #expect(throws: Institute.Error.self) {
            _ = try await seal.run()
        }
    }

    @Test
    func
        `check reports no diagnostics for a receipt whose blobs resolve and evaluation is internally consistent`()
        throws
    {
        let fixture = try Institute.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        let readme = Institute.Conversion.Test.page(
            "swift-primitives/swift-example-one",
            pre: "blob-pre",
            post: "blob-post"
        )
        let receipt = Institute.Conversion.Receipt(
            instrument: Institute.Conversion.Test.instrument(),
            cohort: [Institute.Conversion.Test.cohortEntry("swift-primitives/swift-example-one")],
            pages: [readme],
            driftChecks: [],
            evaluation: .init(
                protocolFreezeBlob: Institute.Conversion.protocolBlob,
                appendixBlob: "appendix-blob",
                executorBinding: ["model": "test-model"],
                trials: [
                    .init(
                        trialIdentifier: "t-1-L",
                        coordinate: Institute.Conversion.Test.coordinate(
                            "swift-primitives/swift-example-one"
                        ),
                        template: "T1",
                        arm: .legacy,
                        readmeBlob: "blob-pre",
                        transcriptDigest: "transcript-1",
                        tokenCount: 10,
                        turnCount: 1,
                        durationSeconds: 1.0,
                        finalAnswer: "[]",
                        score: true,
                        scoringRule: "T1-set-equality"
                    ),
                    .init(
                        trialIdentifier: "t-1-C",
                        coordinate: Institute.Conversion.Test.coordinate(
                            "swift-primitives/swift-example-one"
                        ),
                        template: "T1",
                        arm: .converted,
                        readmeBlob: "blob-post",
                        transcriptDigest: "transcript-2",
                        tokenCount: 12,
                        turnCount: 1,
                        durationSeconds: 1.2,
                        finalAnswer: "[]",
                        score: true,
                        scoringRule: "T1-set-equality"
                    ),
                ],
                summary: .init(
                    excluded: 0,
                    notApplicable: 0,
                    unmeasured: 0,
                    pairCount: 1,
                    deltaHat: 0,
                    ciLower: -0.02,
                    ciUpper: 0.02,
                    decision: .proceed
                )
            )
        )

        let diagnostics = Institute.Conversion.Check.diagnostics(
            for: receipt,
            root: fixture.root,
            resolves: { _, _, _ in true }
        )
        #expect(diagnostics.isEmpty)
    }

    @Test
    func
        `check flags a receipt whose protocolFreezeBlob differs from the instrument and whose decision is not invalid`()
        throws
    {
        let fixture = try Institute.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        let readme = Institute.Conversion.Test.page(
            "swift-primitives/swift-example-one",
            pre: "blob-pre",
            post: "blob-post"
        )
        let receipt = Institute.Conversion.Receipt(
            instrument: Institute.Conversion.Test.instrument(),
            cohort: [Institute.Conversion.Test.cohortEntry("swift-primitives/swift-example-one")],
            pages: [readme],
            driftChecks: [],
            evaluation: .init(
                // Deliberately mismatched against `instrument.protocolBlob`.
                protocolFreezeBlob: "a-different-blob",
                appendixBlob: "appendix-blob",
                executorBinding: ["model": "test-model"],
                trials: [],
                summary: .init(
                    excluded: 0,
                    notApplicable: 0,
                    unmeasured: 0,
                    pairCount: 0,
                    deltaHat: 0,
                    ciLower: 0,
                    ciUpper: 0,
                    decision: .proceed
                )
            )
        )

        let diagnostics = Institute.Conversion.Check.diagnostics(
            for: receipt,
            root: fixture.root,
            resolves: { _, _, _ in true }
        )
        #expect(diagnostics.contains { $0.contains("protocolFreezeBlob") })
    }

    @Test
    func `check reports a missing blob and does not report one that resolves`() throws {
        let fixture = try Institute.Doctor.Fixture(repositories: [])
        defer { fixture.remove() }
        let receipt = Institute.Conversion.Receipt(
            instrument: Institute.Conversion.Test.instrument(),
            cohort: [Institute.Conversion.Test.cohortEntry("swift-primitives/swift-example-one")],
            pages: [
                Institute.Conversion.Test.page(
                    "swift-primitives/swift-example-one",
                    pre: "present-blob"
                )
            ],
            driftChecks: []
        )

        let missing = Institute.Conversion.Check.diagnostics(
            for: receipt,
            root: fixture.root,
            resolves: { _, _, digest in digest != "present-blob" }
        )
        #expect(missing.contains { $0.contains("does not resolve") })

        let present = Institute.Conversion.Check.diagnostics(
            for: receipt,
            root: fixture.root,
            resolves: { _, _, _ in true }
        )
        #expect(present.isEmpty)
    }

    @Test
    func `Revert outcome is computed from blob equality, never authored`() {
        let restored = Institute.Conversion.Revert(
            coordinate: Institute.Conversion.Test.coordinate("swift-primitives/swift-example-one"),
            revertCommit: "commit-1",
            restoredBlob: "blob-pre",
            expectedPreConversionBlob: "blob-pre"
        )
        #expect(restored.outcome == .restored)

        let failed = Institute.Conversion.Revert(
            coordinate: Institute.Conversion.Test.coordinate("swift-primitives/swift-example-one"),
            revertCommit: "commit-1",
            restoredBlob: "wrong-blob",
            expectedPreConversionBlob: "blob-pre"
        )
        #expect(failed.outcome == .failed)
    }
}
