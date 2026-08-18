import Build_Coordinator
import FIPS_180_4
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

extension Institute.Coherence.Receipt {
    /// A verbatim, test-only copy of ``canonical``/`digest(at:)` exactly
    /// as they read on this type before issue #83 Part 1 extracted
    /// ``Institute/Receipt/Sealed`` and deleted these two members from
    /// here. Kept only as an independent reference implementation so the
    /// golden-digest test below can prove each migration is byte-identical
    /// without needing a pre-migration commit checked out — the original
    /// scratch-file-and-`shasum` discipline, computed by code that was
    /// never touched by any migration. Since TX-APP1F this copy is also
    /// the parity witness for the in-process `FIPS_180_4.SHA256` digest
    /// that replaced the `shasum` spawn on the live path.
    fileprivate var legacyCanonical: Swift.String {
        json.serialize(sortKeys: true)
    }

    fileprivate func legacyDigest(at root: Institute.Root) throws(Institute.Error) -> Swift.String {
        let path: File.Path
        do throws(File.Path.Temporary.Error) {
            path = try File.Path.Temporary.sibling(
                of: root.checkout.path,
                prefix: ".workspace-coherence-receipt-legacy-",
                suffix: ".json"
            )
        } catch {
            throw .filesystem(
                "cannot allocate a scratch path for the legacy receipt digest: \(error)"
            )
        }
        let file = File(path)
        do throws(File.System.Write.Atomic.Error) {
            try file.write.atomic(legacyCanonical)
        } catch {
            throw .filesystem("cannot write a scratch legacy receipt for digesting: \(error)")
        }
        defer {
            do { try file.delete() } catch {}
        }
        #if os(Windows)
            // `shasum` is not a Windows binary. The scratch-file
            // round-trip is preserved; only the digest of those bytes is
            // computed in-process. The POSIX legs keep the fully
            // independent platform-tool witness.
            do throws(Either<File.System.Read.Full.Error, Never>) {
                return try file.read.full { bytes in
                    var storage = [Byte]()
                    storage.reserveCapacity(bytes.count)
                    for index in bytes.indices {
                        storage.append(bytes[index])
                    }
                    return FIPS_180_4.SHA256.digest(storage).hex
                }
            } catch {
                throw .filesystem("cannot read the scratch legacy receipt: \(error)")
            }
        #else
            let output = try Institute.Doctor.spawn(
                "shasum",
                arguments: ["-a", "256", file.description]
            )
            guard
                let field = output.split(separator: " ", omittingEmptySubsequences: true).first,
                field.count == 64,
                field.allSatisfy(\.isHexDigit)
            else {
                throw .process(
                    "cannot read a SHA-256 digest for the legacy receipt out of: \(output)"
                )
            }
            return Swift.String(field).lowercased()
        #endif
    }
}

extension Institute.Coherence {
    @Suite
    struct Test {
        @Suite struct Unit {}
        @Suite struct `Edge Case` {}
        @Suite struct Integration {}
    }
}

extension Institute.Coherence.Test {
    /// A repository roster of two, both selected — the canonical (`policy`)
    /// shape most fixtures start from.
    static func repositories() -> [Institute.Repository] {
        [
            Institute.Repository(
                name: "swift-example-one",
                url: "https://github.com/swift-primitives/swift-example-one.git",
                organization: "swift-primitives",
                layer: .primitives
            ),
            Institute.Repository(
                name: "swift-example-two",
                url: "https://github.com/swift-primitives/swift-example-two.git",
                organization: "swift-primitives",
                layer: .primitives
            ),
        ]
    }

    static func report(status errors: Swift.Int) -> Institute.Doctor.Report {
        // An empty-outcome report is a clean (status 0) report; a single
        // synthetic error-finding outcome produces a non-zero status
        // without needing a real check to run.
        guard errors > 0 else { return .init(outcomes: []) }
        let finding = Institute.Doctor.Finding(severity: .error, message: "synthetic")
        return .init(
            outcomes: [
                .init(
                    check: "synthetic",
                    scope: .contributor,
                    result: .finding(severity: .error, population: 1),
                    findings: [finding]
                )
            ]
        )
    }

    static func noop(
        _ root: Institute.Root,
        _ selection: Institute.Selection.Resolved
    ) throws(Institute.Error) {}

    static func succeed(
        _ root: Institute.Root,
        _ selection: Institute.Selection.Resolved
    ) throws(Institute.Error) -> Swift.Int {
        selection.repositories.count
    }

    static func build(
        exitCode: Swift.Int32,
        output: Swift.String = ""
    )
        -> @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute.Error) ->
        Build_Coordinator.Build.Coordinator.Result
    {
        { _, _ throws(Institute.Error) in
            .init(
                exitCode: exitCode,
                standardOutput: Swift.Array(output.utf8),
                standardError: []
            )
        }
    }
}

extension Institute.Coherence.Test.Unit {
    @Test
    func `A canonical run whose sync, doctor, graph, and build all succeed is coherent`()
        async throws
    {
        let fixture = try Institute.Doctor.Fixture(
            repositories: Institute.Coherence.Test.repositories()
        )
        defer { fixture.remove() }

        let run = Institute.Coherence.Run(
            root: fixture.root,
            configuration: fixture.configuration,
            selection: fixture.selection,
            sync: Institute.Coherence.Test.noop,
            doctor: { _, _, _ in Institute.Coherence.Test.report(status: 0) },
            graph: Institute.Coherence.Test.succeed,
            build: Institute.Coherence.Test.build(exitCode: 0)
        )

        let receipt = await run.run()

        #expect(receipt.verdict == .coherent)
        #expect(receipt.attribution == nil)
        #expect(receipt.population.inventoryCount == 2)
        #expect(receipt.population.materializedCount == 2)
        #expect(receipt.population.builtTargetCount == receipt.population.expectedTargetCount)
        #expect(
            receipt.stages.map(\.stage) == [
                .bootstrap, .sync, .doctor, .graph, .build, .population,
            ]
        )
        #expect(receipt.stages.allSatisfy { $0.outcome == .success })
        #expect(receipt.instrument.buildPath == "xcodebuild-merged")
    }

    @Test
    func `A run selecting swiftpm-composed-root records that build path on the receipt`()
        async throws
    {
        let fixture = try Institute.Doctor.Fixture(
            repositories: Institute.Coherence.Test.repositories()
        )
        defer { fixture.remove() }

        let run = Institute.Coherence.Run(
            root: fixture.root,
            configuration: fixture.configuration,
            selection: fixture.selection,
            buildPath: .swiftPMComposedRoot,
            sync: Institute.Coherence.Test.noop,
            doctor: { _, _, _ in Institute.Coherence.Test.report(status: 0) },
            graph: Institute.Coherence.Test.succeed,
            build: Institute.Coherence.Test.build(exitCode: 0)
        )

        let receipt = await run.run()

        #expect(receipt.verdict == .coherent)
        #expect(receipt.instrument.buildPath == "swiftpm-composed-root")
    }

    @Test
    func `A receipt round-trips through JSON and its digest is stable across two computations`()
        async throws
    {
        let fixture = try Institute.Doctor.Fixture(
            repositories: Institute.Coherence.Test.repositories()
        )
        defer { fixture.remove() }

        let run = Institute.Coherence.Run(
            root: fixture.root,
            configuration: fixture.configuration,
            selection: fixture.selection,
            sync: Institute.Coherence.Test.noop,
            doctor: { _, _, _ in Institute.Coherence.Test.report(status: 0) },
            graph: Institute.Coherence.Test.succeed,
            build: Institute.Coherence.Test.build(exitCode: 0)
        )
        let receipt = await run.run()

        let decoded = try Institute.Coherence.Receipt(jsonString: receipt.canonical)
        #expect(decoded == receipt)

        let first = receipt.digest
        let second = receipt.digest
        #expect(first == second)
        #expect(first.count == 64)
        #expect(first.allSatisfy { $0.isHexDigit })
    }

    @Test
    func
        `Issue 83 Part 1 — the migration to Institute Receipt Sealed changed neither canonical text nor digest`()
        async throws
    {
        let fixture = try Institute.Doctor.Fixture(
            repositories: Institute.Coherence.Test.repositories()
        )
        defer { fixture.remove() }

        let run = Institute.Coherence.Run(
            root: fixture.root,
            configuration: fixture.configuration,
            selection: fixture.selection,
            sync: Institute.Coherence.Test.noop,
            doctor: { _, _, _ in Institute.Coherence.Test.report(status: 0) },
            graph: Institute.Coherence.Test.succeed,
            build: Institute.Coherence.Test.build(exitCode: 0)
        )
        let receipt = await run.run()

        // `legacyCanonical`/`legacyDigest(at:)` are a frozen, test-only copy
        // of exactly what `Institute.Coherence.Receipt.canonical` and
        // `.digest(at:)` read before issue #83 Part 1 deleted them in favor
        // of `Institute.Receipt.Sealed`. A migration that changed either
        // computation is a regression, not a refactor (issue #83's Part 1
        // acceptance criterion) — this fails the instant the two disagree.
        // Since TX-APP1F the same comparison is the behavioural-parity
        // proof that the in-process `FIPS_180_4.SHA256` witness digests
        // byte-identically to the platform `shasum` spawn it replaced.
        #expect(receipt.canonical == receipt.legacyCanonical)
        #expect(receipt.digest == (try receipt.legacyDigest(at: fixture.root)))
    }

    @Test
    func `A seeded compile failure names its package, the build stage, and the diagnostic`()
        async throws
    {
        let fixture = try Institute.Doctor.Fixture(
            repositories: Institute.Coherence.Test.repositories()
        )
        defer { fixture.remove() }
        let culprit = Institute.Coherence.Test.repositories()[1]
        let location = try fixture.root.materialization(for: culprit)
        let diagnostic = "\(location.description)/Sources/Foo.swift:12:5: error: cannot find 'x'"

        let run = Institute.Coherence.Run(
            root: fixture.root,
            configuration: fixture.configuration,
            selection: fixture.selection,
            sync: Institute.Coherence.Test.noop,
            doctor: { _, _, _ in Institute.Coherence.Test.report(status: 0) },
            graph: Institute.Coherence.Test.succeed,
            build: Institute.Coherence.Test.build(exitCode: 1, output: diagnostic)
        )
        let receipt = await run.run()

        #expect(receipt.verdict == .incoherent)
        #expect(receipt.attribution?.stage == .build)
        #expect(receipt.attribution?.package == culprit.name)
        #expect(receipt.attribution?.organization == culprit.organization)
        #expect(receipt.attribution?.firstDiagnostic == diagnostic)
        #expect(receipt.stages.last(where: { $0.stage == .population })?.outcome == .notRun)
    }

    @Test
    func
        `A canonical selection short of the inventory fails as unmeasured even when the build succeeds`()
        async throws
    {
        let repositories = Institute.Coherence.Test.repositories()
        let fixture = try Institute.Doctor.Fixture(
            repositories: repositories,
            selected: [repositories[0]],
            // Deliberately mis-declared as canonical to simulate a build
            // that silently selected less than the roster — the exact
            // shape the population control exists to catch.
            origin: .committed(count: 1)
        )
        defer { fixture.remove() }

        let run = Institute.Coherence.Run(
            root: fixture.root,
            configuration: fixture.configuration,
            selection: fixture.selection,
            sync: Institute.Coherence.Test.noop,
            doctor: { _, _, _ in Institute.Coherence.Test.report(status: 0) },
            graph: Institute.Coherence.Test.succeed,
            build: Institute.Coherence.Test.build(exitCode: 0)
        )
        let receipt = await run.run()

        #expect(receipt.verdict == .unmeasured)
        #expect(receipt.population.inventoryCount == 2)
        #expect(receipt.population.materializedCount == 1)
        #expect(receipt.instrument.selection == "policy")
    }

    @Test
    func `A narrowed selection is marked non-canonical rather than failing the population control`()
        async throws
    {
        let repositories = Institute.Coherence.Test.repositories()
        let fixture = try Institute.Doctor.Fixture(
            repositories: repositories,
            selected: [repositories[0]],
            origin: .overridden(
                committed: 2,
                added: [],
                removed: [
                    Institute.Repository.Key(
                        identity: "\(repositories[1].organization)/\(repositories[1].name)"
                    )!
                ]
            )
        )
        defer { fixture.remove() }

        let run = Institute.Coherence.Run(
            root: fixture.root,
            configuration: fixture.configuration,
            selection: fixture.selection,
            sync: Institute.Coherence.Test.noop,
            doctor: { _, _, _ in Institute.Coherence.Test.report(status: 0) },
            graph: Institute.Coherence.Test.succeed,
            build: Institute.Coherence.Test.build(exitCode: 0)
        )
        let receipt = await run.run()

        #expect(receipt.verdict == .coherent)
        #expect(receipt.instrument.selection != "policy")
    }

    @Test
    func `A sync failure is unmeasured and every later stage is recorded not-run`() async throws {
        let fixture = try Institute.Doctor.Fixture(
            repositories: Institute.Coherence.Test.repositories()
        )
        defer { fixture.remove() }

        let run = Institute.Coherence.Run(
            root: fixture.root,
            configuration: fixture.configuration,
            selection: fixture.selection,
            sync: { _, _ throws(Institute.Error) in throw .repository("synthetic sync failure") },
            doctor: { _, _, _ in Institute.Coherence.Test.report(status: 0) },
            graph: Institute.Coherence.Test.succeed,
            build: Institute.Coherence.Test.build(exitCode: 0)
        )
        let receipt = await run.run()

        #expect(receipt.verdict == .unmeasured)
        #expect(receipt.attribution == nil)
        let byStage = Swift.Dictionary(
            uniqueKeysWithValues: receipt.stages.map { ($0.stage, $0.outcome) }
        )
        #expect(byStage[.sync] == .failure)
        #expect(byStage[.doctor] == .notRun)
        #expect(byStage[.graph] == .notRun)
        #expect(byStage[.build] == .notRun)
        #expect(byStage[.population] == .notRun)
    }
}
