import Byte
public import Institute_Model
import Institute_Repository_Application
import Institute_Repository_Policy
import Testing

@Suite
struct `Repository Policy Uniformity Wave Tests` {
    /// The embedded payload is the ratification: exactly the bytes the
    /// principal ratified on swift-institute/.github#600 — shape policy 5,
    /// 522 UTF-8 bytes — and `canonical()` refuses drift by digest.
    @Test
    func embeddedPayloadCarriesTheExactRatifiedBytes() throws {
        let payload = try Institute.Repository.Policy.Uniformity.Wave.Payload.canonical()

        #expect(payload.count == 522)
        #expect(
            Institute.Repository.Policy.Caller.Wave.digest(payload)
                == "8e37977a3b8f0a0d9e028e6089172d811eea21e6868a878ab43a1d4875df02f7"
        )
        #expect(
            Institute.Repository.Policy.Uniformity.Wave.Payload.digest
                == "8e37977a3b8f0a0d9e028e6089172d811eea21e6868a878ab43a1d4875df02f7"
        )
        #expect(
            String(decoding: payload, as: UTF8.self).contains(
                "# Canonical Swift package shape policy: 5 (absolute allowlist)"
            )
        )
    }

    @Test
    func enumeratesEveryActiveOrganizationIntoOneSortedPopulation() async throws {
        let client = UniformityWaveMockClient(
            ruleset: try ruleset(),
            shape: nonterminalShape
        )
        let population = try await Institute.Repository.Policy.Uniformity.Wave.enumerate(
            client: client,
            fleet: try fleet(organizations: ["swift-standards", "swift-primitives"])
        )

        #expect(population.organizations == ["swift-primitives", "swift-standards"])
        #expect(population.examined == 2)
        #expect(
            population.subjects.map(\.repository)
                == ["swift-primitives/example", "swift-standards/example"]
        )
        #expect(
            population.subjects.allSatisfy {
                $0.shape.presentDeletions
                    == Institute.Repository.Policy.Uniformity.Wave.Shape.deletionPaths
            }
        )
    }

    @Test
    func privateOnlyOrganizationBecomesATypedExclusionNotAMatrixRow() async throws {
        let client = UniformityWaveMockClient(
            ruleset: try ruleset(),
            shape: nonterminalShape,
            privateOrganizations: ["swift-riscv"]
        )
        let population = try await Institute.Repository.Policy.Uniformity.Wave.enumerate(
            client: client,
            fleet: try fleet(organizations: ["swift-primitives", "swift-riscv"])
        )

        #expect(population.subjectOrganizations == ["swift-primitives"])
        #expect(
            population.organizationExclusions == [
                .init(
                    organization: "swift-riscv",
                    reason: Institute.Repository.Policy.Uniformity.Wave
                        .OrganizationExclusion.privateOnly
                )
            ]
        )
    }

    @Test
    func emptyOrganizationEnumerationRefusesThePopulation() async throws {
        let client = UniformityWaveMockClient(
            ruleset: try ruleset(),
            shape: nonterminalShape,
            emptyRepositories: true
        )

        await #expect(throws: Institute.Repository.Policy.Uniformity.Wave.Error.self) {
            try await Institute.Repository.Policy.Uniformity.Wave.enumerate(
                client: client,
                fleet: try fleet(organizations: ["swift-primitives"])
            )
        }
    }

    /// The requirement is the Swift owner's audited arithmetic; the
    /// largest current organization must fit GitHub's hard 12,500/h
    /// installation cap, and a short pool still refuses.
    @Test
    func capacityRequirementIsOwnedPricedAndStillRefusesShortPools() {
        let largest = Institute.Repository.Policy.Uniformity.Wave.Capacity.requirement(subjects: 206)
        #expect(largest == 206 * 58 + 160)
        #expect(largest <= 12_500)
        #expect(Institute.Repository.Policy.Uniformity.Wave.Capacity.requirement(subjects: 1) == 218)

        let short = Institute.Repository.Policy.Caller.Wave.Capacity(
            remaining: largest - 1,
            required: largest,
            resetAt: 1_787_000_000
        )
        #expect(!short.accepted)
    }

    @Test
    func preflightAcceptsTheExactTokenIssuanceAttestation() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let evidence = try attestation(fixture: "uniformity-attestation-positive")

        let result = try await Institute.Repository.Policy.Uniformity.Wave.preflight(
            client: client,
            request: request,
            attestation: evidence.attestation,
            attestationDigest: evidence.digest
        )

        #expect(result.receipt.accepted)
        #expect(result.receipt.attestationDigest == evidence.digest)
        #expect(result.receipt.organization == "swift-institute")
        #expect(result.recovery.shape == nonterminalShape)
        #expect(result.recovery.rollbackHead == "old-head")
        #expect(
            result.receipt.recoveryDigest
                == Institute.Repository.Policy.Caller.Wave.digest(
                    Institute.Repository.Policy.Caller.Wave.evidenceBytes(result.recovery)
                )
        )
    }

    /// `workflows-granted` is the uniformity-specific negative control:
    /// this wave never touches a workflow file, so a token that could is
    /// over-privileged and preflight refuses it before any measurement.
    @Test(arguments: [
        "uniformity-attestation-missing-contents",
        "uniformity-attestation-missing-administration",
        "uniformity-attestation-workflows-granted",
        "uniformity-attestation-foreign-scope",
    ])
    func preflightRefusesAnAttestationOutsideTheExactGrant(
        fixture: String
    ) async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let evidence = try attestation(fixture: fixture)

        await #expect(throws: Institute.Repository.Policy.Uniformity.Wave.Error.self) {
            try await Institute.Repository.Policy.Uniformity.Wave.preflight(
                client: client,
                request: request,
                attestation: evidence.attestation,
                attestationDigest: evidence.digest
            )
        }
        #expect(await client.replacements() == 0)
    }

    @Test
    func preflightRefusesAPayloadThatIsNotTheRatifiedBytes() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical, payload: [Byte](utf8: "drifted\n"))
        let evidence = try attestation(fixture: "uniformity-attestation-positive")

        await #expect(throws: Institute.Repository.Policy.Uniformity.Wave.Error.self) {
            try await Institute.Repository.Policy.Uniformity.Wave.preflight(
                client: client,
                request: request,
                attestation: evidence.attestation,
                attestationDigest: evidence.digest
            )
        }
        #expect(await client.replacements() == 0)
    }

    @Test
    func appliesForwardShapeCommitAndClosesTheWindow() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        var events: [Institute.Repository.Policy.Uniformity.Wave.Event] = []

        let receipt = try await Institute.Repository.Policy.Uniformity.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { events.append($0) }
        )

        #expect(receipt.changed)
        #expect(receipt.shapeChanged)
        #expect(!receipt.rulesetChanged)
        #expect(receipt.oldHead == "old-head")
        #expect(receipt.newHead == "new-head")
        #expect(receipt.oldGitignore == "old-gitignore")
        #expect(receipt.newGitignore == "new-blob")
        #expect(
            receipt.deleted == Institute.Repository.Policy.Uniformity.Wave.Shape.deletionPaths
        )
        #expect(receipt.bypassClosed)
        #expect(events.map(\.phase) == ["window-opening", "applied"])
        #expect(
            await client.deletions()
                == Institute.Repository.Policy.Uniformity.Wave.Shape.deletionPaths
        )
        #expect(await client.replacements() == 2)
    }

    /// The idempotent fresh-dispatch path: a subject already carrying the
    /// exact ratified bytes with all three retired files absent is
    /// re-receipted as converged without any commit or ref move.
    @Test
    func alreadyTerminalSubjectIsReReceiptedWithoutMutation() async throws {
        let canonical = try ruleset()
        let terminal = Institute.Repository.Policy.Uniformity.Wave.Shape(
            gitignore: .init(
                blob: "terminal-gitignore",
                bytes: Institute.Repository.Policy.Uniformity.Wave.Payload.bytes
            ),
            swiftlint: nil,
            swiftFormat: nil,
            dependabot: nil
        )
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: terminal
        )
        let request = request(canonical: canonical, shape: terminal)
        let recovery = try await preflight(client: client, request: request)
        var events: [Institute.Repository.Policy.Uniformity.Wave.Event] = []

        let receipt = try await Institute.Repository.Policy.Uniformity.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { events.append($0) }
        )

        #expect(!receipt.shapeChanged)
        #expect(!receipt.changed)
        #expect(receipt.newHead == "old-head")
        #expect(receipt.deleted.isEmpty)
        #expect(receipt.bypassClosed)
        #expect(events.map(\.phase) == ["already-terminal"])
        #expect(await client.commits() == 0)
        #expect(await client.moves() == 0)
        #expect(await client.replacements() == 0)
    }

    @Test
    func createsMissingRulesetEvenWhenShapeIsAlreadyTerminal() async throws {
        let canonical = try ruleset()
        let terminal = Institute.Repository.Policy.Uniformity.Wave.Shape(
            gitignore: .init(
                blob: "terminal-gitignore",
                bytes: Institute.Repository.Policy.Uniformity.Wave.Payload.bytes
            ),
            swiftlint: nil,
            swiftFormat: nil,
            dependabot: nil
        )
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: terminal,
            rulesetAbsent: true
        )
        let request = request(canonical: canonical, shape: terminal)
        let recovery = try await preflight(client: client, request: request)
        var events: [Institute.Repository.Policy.Uniformity.Wave.Event] = []

        let receipt = try await Institute.Repository.Policy.Uniformity.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { events.append($0) }
        )

        #expect(!receipt.shapeChanged)
        #expect(receipt.rulesetChanged)
        #expect(recovery.priorRuleset == nil)
        #expect(events.map(\.phase) == ["ruleset-converged", "already-terminal"])
        #expect(await client.creations() == 1)
        #expect(await client.commits() == 0)
    }

    @Test
    func movedHeadRefusesBeforeWindow() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setHead("other-head")

        await #expect(throws: Institute.Repository.Policy.Uniformity.Wave.Error.self) {
            try await Institute.Repository.Policy.Uniformity.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 0)
    }

    @Test
    func movedShapeRefusesBeforeWindow() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setShape(
            .init(
                gitignore: .init(blob: "moved-gitignore", bytes: [Byte](utf8: "moved\n")),
                swiftlint: "lint-blob",
                swiftFormat: "format-blob",
                dependabot: "dependabot-blob"
            )
        )

        await #expect(throws: Institute.Repository.Policy.Uniformity.Wave.Error.self) {
            try await Institute.Repository.Policy.Uniformity.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 0)
    }

    /// The byte-mismatch negative control: a verified head whose
    /// `.gitignore` does not carry the exact ratified bytes refuses the
    /// transaction, and the bypass is still closed on the way out.
    @Test
    func byteMismatchAfterCommitRefusesAndClosesTheBypass() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setBrokenBytesAfterMove()

        await #expect(throws: Institute.Repository.Policy.Uniformity.Wave.Error.self) {
            try await Institute.Repository.Policy.Uniformity.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(!(await client.bypassOpen(integrationID: request.integrationID)))
    }

    /// The deletion-verification negative control: a retired file that
    /// survives the commit refuses the transaction with the bypass
    /// closed.
    @Test
    func survivingDeletionAfterCommitRefusesAndClosesTheBypass() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setSurvivingDeletionAfterMove()

        await #expect(throws: Institute.Repository.Policy.Uniformity.Wave.Error.self) {
            try await Institute.Repository.Policy.Uniformity.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(!(await client.bypassOpen(integrationID: request.integrationID)))
    }

    @Test
    func interruptionAfterOpeningStillClosesTheBypass() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setCommitFailure()

        await #expect(throws: Institute.Repository.Policy.Uniformity.Wave.Error.self) {
            try await Institute.Repository.Policy.Uniformity.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(!(await client.bypassOpen(integrationID: request.integrationID)))
    }

    @Test
    func failedMoveClosesTheBypass() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setMoveFailure()

        await #expect(throws: Institute.Repository.Policy.Uniformity.Wave.Error.self) {
            try await Institute.Repository.Policy.Uniformity.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(!(await client.bypassOpen(integrationID: request.integrationID)))
        #expect(await client.replacements() == 2)
    }

    @Test
    func durablePreflightEvidenceClosesABypassAfterRunnerLoss() async throws {
        let canonical = try ruleset()
        let client = UniformityWaveMockClient(
            ruleset: canonical,
            shape: nonterminalShape
        )
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        try await client.openBypass(integrationID: request.integrationID)

        let closure = try await Institute.Repository.Policy.Uniformity.Wave.close(
            client: client,
            recovery: recovery,
            payload: request.payload
        )

        #expect(closure.bypassClosed)
        #expect(closure.rulesetCanonical)
        #expect(!closure.accepted)
        #expect(!(await client.bypassOpen(integrationID: request.integrationID)))
    }

    @Test
    func recensusRequiresTheExactOriginalPopulationAndEvidenceSet() throws {
        let evidence = try recensusEvidence()
        let receipt = try Institute.Repository.Policy.Uniformity.Wave.recensus(
            original: evidence.original,
            current: evidence.current,
            evidence: recensusInput(evidence)
        )

        #expect(receipt.accepted)
        #expect(receipt.observations.allSatisfy { $0.matches })
    }

    @Test
    func recensusRefusesOneMissingClosureFromANonemptyFleet() throws {
        let evidence = try recensusEvidence()
        let receipt = try Institute.Repository.Policy.Uniformity.Wave.recensus(
            original: evidence.original,
            current: evidence.current,
            evidence: recensusInput(
                evidence,
                closures: Array(evidence.closures.dropLast())
            )
        )

        #expect(!receipt.accepted)
    }

    @Test
    func recensusRefusesASubjectWhoseGitignoreBytesDrifted() throws {
        let evidence = try recensusEvidence()
        var subjects = evidence.current.subjects
        subjects[subjects.count - 1] = Institute.Repository.Policy.Uniformity.Wave.Subject(
            repository: subjects[subjects.count - 1].repository,
            repositoryID: subjects[subjects.count - 1].repositoryID,
            head: subjects[subjects.count - 1].head,
            manifest: subjects[subjects.count - 1].manifest,
            shape: .init(
                gitignore: .init(
                    blob: subjects[subjects.count - 1].shape.gitignore?.blob ?? "blob",
                    bytes: [Byte](utf8: "drifted\n")
                ),
                swiftlint: nil,
                swiftFormat: nil,
                dependabot: nil
            )
        )
        let current = Institute.Repository.Policy.Uniformity.Wave.Population(
            organizations: evidence.current.organizations,
            examined: evidence.current.examined,
            repositoryCounts: evidence.current.repositoryCounts,
            repositories: evidence.current.repositories,
            excluded: evidence.current.excluded,
            subjects: subjects
        )

        let receipt = try Institute.Repository.Policy.Uniformity.Wave.recensus(
            original: evidence.original,
            current: current,
            evidence: recensusInput(evidence)
        )

        #expect(!receipt.accepted)
    }

    // MARK: - Helpers

    private var nonterminalShape: Institute.Repository.Policy.Uniformity.Wave.Shape {
        .init(
            gitignore: .init(blob: "old-gitignore", bytes: [Byte](utf8: "old\n")),
            swiftlint: "lint-blob",
            swiftFormat: "format-blob",
            dependabot: "dependabot-blob"
        )
    }

    private func request(
        canonical: [Byte],
        shape: Institute.Repository.Policy.Uniformity.Wave.Shape? = nil,
        payload: [Byte]? = nil
    ) -> Institute.Repository.Policy.Uniformity.Wave.Request {
        .init(
            repository: "swift-institute/example",
            expectedRepositoryID: 1,
            expectedHead: "old-head",
            expectedManifest: .init(kind: "file", blob: "manifest-blob"),
            expectedShape: shape ?? nonterminalShape,
            payload: payload ?? Institute.Repository.Policy.Uniformity.Wave.Payload.bytes,
            canonicalRuleset: canonical,
            integrationID: 3_543_256,
            population: .init(
                repositories: 1,
                subjects: 1,
                repositoryDigest: "repositories",
                subjectDigest: "subjects",
                stateDigest: "state"
            ),
            policyDigest: policyDigest,
            policySource: policySource,
            commitMessage: "Adopt the canonical package shape policy [skip ci]"
        )
    }

    private func preflight(
        client: UniformityWaveMockClient,
        request: Institute.Repository.Policy.Uniformity.Wave.Request
    ) async throws -> Institute.Repository.Policy.Uniformity.Wave.Recovery {
        let evidence = try attestation(fixture: "uniformity-attestation-positive")
        let result = try await Institute.Repository.Policy.Uniformity.Wave.preflight(
            client: client,
            request: request,
            attestation: evidence.attestation,
            attestationDigest: evidence.digest
        )
        return result.recovery
    }

    private func attestation(
        fixture: String
    ) throws -> (attestation: Institute.Repository.Policy.Uniformity.Wave.Attestation, digest: String) {
        let path = try #require(UniformityWaveFoundation.fixturePath(forResource: fixture, withExtension: "json"))
        return try Institute.Repository.Policy.Uniformity.Wave.Attestation.read(at: path)
    }

    private func recensusEvidence() throws -> (
        original: Institute.Repository.Policy.Uniformity.Wave.Population,
        current: Institute.Repository.Policy.Uniformity.Wave.Population,
        receipts: [Institute.Repository.Policy.Uniformity.Wave.Receipt],
        events: [Institute.Repository.Policy.Uniformity.Wave.Event],
        closures: [Institute.Repository.Policy.Uniformity.Wave.Closure]
    ) {
        let payload = Institute.Repository.Policy.Uniformity.Wave.Payload.bytes
        let payloadDigest = Institute.Repository.Policy.Caller.Wave.digest(payload)
        let repositories = ["swift-primitives/a", "swift-primitives/b"]
        let originalSubjects = repositories.enumerated().map { offset, repository in
            Institute.Repository.Policy.Uniformity.Wave.Subject(
                repository: repository,
                repositoryID: Int64(offset + 1),
                head: "old-head-\(offset)",
                manifest: .init(kind: "file", blob: "manifest-\(offset)"),
                shape: .init(
                    gitignore: .init(blob: "old-blob-\(offset)", bytes: [Byte](utf8: "old\n")),
                    swiftlint: "lint-\(offset)",
                    swiftFormat: nil,
                    dependabot: nil
                )
            )
        }
        let currentSubjects = repositories.enumerated().map { offset, repository in
            Institute.Repository.Policy.Uniformity.Wave.Subject(
                repository: repository,
                repositoryID: Int64(offset + 1),
                head: "new-head-\(offset)",
                manifest: .init(kind: "file", blob: "manifest-\(offset)"),
                shape: .init(
                    gitignore: .init(blob: "new-blob-\(offset)", bytes: payload),
                    swiftlint: nil,
                    swiftFormat: nil,
                    dependabot: nil
                )
            )
        }
        let original = Institute.Repository.Policy.Uniformity.Wave.Population(
            organizations: ["swift-primitives"],
            examined: 2,
            repositoryCounts: ["swift-primitives": 2],
            repositories: repositories,
            excluded: [:],
            subjects: originalSubjects
        )
        let current = Institute.Repository.Policy.Uniformity.Wave.Population(
            organizations: ["swift-primitives"],
            examined: 2,
            repositoryCounts: ["swift-primitives": 2],
            repositories: repositories,
            excluded: [:],
            subjects: currentSubjects
        )
        let receipts = repositories.indices.map { index in
            Institute.Repository.Policy.Uniformity.Wave.Receipt(
                repository: repositories[index],
                oldHead: originalSubjects[index].head,
                newHead: currentSubjects[index].head,
                oldGitignore: originalSubjects[index].shape.gitignore?.blob,
                newGitignore: currentSubjects[index].shape.gitignore?.blob ?? "",
                deleted: [Institute.Repository.Policy.Uniformity.Wave.Shape.swiftlintPath],
                ruleset: 7,
                shapeChanged: true,
                rulesetChanged: false,
                bypassClosed: true,
                population: original.commitment,
                policyDigest: policyDigest,
                policySource: policySource
            )
        }
        let events = repositories.indices.map { index in
            Institute.Repository.Policy.Uniformity.Wave.Event(
                phase: "applied",
                repository: repositories[index],
                oldHead: originalSubjects[index].head,
                newHead: currentSubjects[index].head,
                oldGitignore: originalSubjects[index].shape.gitignore?.blob,
                newGitignore: currentSubjects[index].shape.gitignore?.blob,
                deletions: [Institute.Repository.Policy.Uniformity.Wave.Shape.swiftlintPath],
                ruleset: 7,
                bypassClosed: true,
                populationDigest: original.commitment.stateDigest,
                policyDigest: policyDigest,
                policySource: policySource
            )
        }
        let closures = repositories.indices.map { index in
            Institute.Repository.Policy.Uniformity.Wave.Closure(
                repository: repositories[index],
                head: currentSubjects[index].head,
                gitignore: currentSubjects[index].shape.gitignore?.blob,
                gitignoreDigest: payloadDigest,
                shapeTerminal: true,
                subjectStable: true,
                ruleset: 7,
                rulesetCanonical: true,
                bypassClosed: true,
                population: original.commitment,
                policyDigest: policyDigest,
                policySource: policySource
            )
        }
        return (original, current, receipts, events, closures)
    }

    private func recensusInput(
        _ evidence: (
            original: Institute.Repository.Policy.Uniformity.Wave.Population,
            current: Institute.Repository.Policy.Uniformity.Wave.Population,
            receipts: [Institute.Repository.Policy.Uniformity.Wave.Receipt],
            events: [Institute.Repository.Policy.Uniformity.Wave.Event],
            closures: [Institute.Repository.Policy.Uniformity.Wave.Closure]
        ),
        closures: [Institute.Repository.Policy.Uniformity.Wave.Closure]? = nil
    ) -> Institute.Repository.Policy.Uniformity.Wave.Recensus.Evidence {
        .init(
            payload: Institute.Repository.Policy.Uniformity.Wave.Payload.bytes,
            receipts: evidence.receipts,
            events: evidence.events,
            closures: closures ?? evidence.closures,
            policyDigest: policyDigest,
            policySource: policySource
        )
    }

    private var policyDigest: String { String(repeating: "b", count: 64) }
    private var policySource: String { String(repeating: "a", count: 40) }

    private func ruleset(enforcement: String = "active") throws -> [Byte] {
        try UniformityWaveFoundation.sortedKeysJSONBytes(
            withJSONObject: [
                "name": "Institute protected main",
                "target": "branch",
                "enforcement": enforcement,
                "bypass_actors": [],
                "conditions": [
                    "ref_name": ["include": ["refs/heads/main"], "exclude": []]
                ],
                "rules": [
                    ["type": "deletion"],
                    ["type": "non_fast_forward"],
                    ["type": "pull_request", "parameters": ["required_approving_review_count": 1]],
                    [
                        "type": "required_status_checks",
                        "parameters": [
                            "required_status_checks": [["context": "ci / matrix / ci-ok"]]
                        ],
                    ],
                ],
            ]
        )
    }

    private func fleet(organizations: [String]) throws -> Institute.Repository.Policy.Fleet {
        let values = organizations.map {
            ["name": $0, "layer": "L1", "status": "active"]
        }
        return try UniformityWaveFoundation.decode(
            Institute.Repository.Policy.Fleet.self,
            fromJSONObject: ["schemaVersion": 1, "organizations": values]
        )
    }
}
