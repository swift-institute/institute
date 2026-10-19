import Byte
import Institute_GitHub
public import Institute_Model
import Institute_Repository_Application
import Institute_Repository_Policy
import Testing

@Suite
struct `Repository Policy Caller Wave Tests` {
    @Test
    func enumeratesEveryActiveOrganizationIntoOneSortedPopulation() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let population = try await Institute.Repository.Policy.Caller.Wave.enumerate(
            client: client,
            fleet: try fleet(organizations: ["swift-standards", "swift-primitives"])
        )

        #expect(population.organizations == ["swift-primitives", "swift-standards"])
        #expect(population.examined == 2)
        #expect(
            population.subjects.map(\.repository)
                == ["swift-primitives/example", "swift-standards/example"]
        )
    }

    /// The negative control for wave run 31817391995's swift-riscv
    /// failure: a fabricated organization whose only repository is
    /// private yields a typed `private-only` exclusion and no matrix
    /// row — never a preflight failure.
    @Test
    func privateOnlyOrganizationBecomesATypedExclusionNotAMatrixRow() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(
            ruleset: canonical,
            privateOrganizations: ["swift-riscv"]
        )
        let population = try await Institute.Repository.Policy.Caller.Wave.enumerate(
            client: client,
            fleet: try fleet(organizations: ["swift-primitives", "swift-riscv"])
        )

        // The full organization set still records the fleet exactly.
        #expect(population.organizations == ["swift-primitives", "swift-riscv"])
        // The matrix set carries only subject-bearing organizations.
        #expect(population.subjectOrganizations == ["swift-primitives"])
        #expect(
            population.organizationExclusions == [
                .init(
                    organization: "swift-riscv",
                    reason: Institute.Repository.Policy.Caller.Wave.Population
                        .OrganizationExclusion.privateOnly
                )
            ]
        )
        #expect(population.subjects.map(\.repository) == ["swift-primitives/example"])
        // Positive control: with every organization subject-bearing,
        // the exclusion list is empty and matrix == organizations.
        let full = try await Institute.Repository.Policy.Caller.Wave.enumerate(
            client: CallerWaveMockClient(ruleset: canonical),
            fleet: try fleet(organizations: ["swift-primitives", "swift-riscv"])
        )
        #expect(full.subjectOrganizations == full.organizations)
        #expect(full.organizationExclusions.isEmpty)
    }

    /// A zero-subject organization that does have public repositories is
    /// excluded as `no-subjects`, keeping the two reasons distinct.
    @Test
    func publicButSubjectlessOrganizationIsExcludedAsNoSubjects() {
        let subject = Institute.Repository.Policy.Caller.Wave.Subject(
            repository: "swift-primitives/example",
            repositoryID: 1,
            head: "head",
            manifest: .init(kind: "file", blob: "manifest"),
            caller: .init(blob: "blob", bytes: [Byte](utf8: "caller\n"))
        )
        let population = Institute.Repository.Policy.Caller.Wave.Population(
            organizations: ["swift-empty", "swift-primitives"],
            examined: 2,
            repositoryCounts: ["swift-empty": 1, "swift-primitives": 1],
            repositories: ["swift-empty/archived", "swift-primitives/example"],
            excluded: ["archived": 1],
            subjects: [subject]
        )
        #expect(population.subjectOrganizations == ["swift-primitives"])
        #expect(
            population.organizationExclusions == [
                .init(
                    organization: "swift-empty",
                    reason: Institute.Repository.Policy.Caller.Wave.Population
                        .OrganizationExclusion.noSubjects
                )
            ]
        )
    }

    /// The capacity requirement is the Swift owner's arithmetic, priced
    /// from measurement: 8 requests per preflighted subject (counted
    /// through an instrumented endpoint), audited apply/close paths,
    /// and the retry budget. The largest current organization (206
    /// subjects) must fit GitHub's hard 12,500/h installation cap — the
    /// former host-side 64/subject estimate did not — while the gate
    /// still refuses a genuinely short pool.
    @Test
    func capacityRequirementIsOwnedPricedAndStillRefusesShortPools() {
        let largest = Institute.Repository.Policy.Caller.Wave.Capacity.requirement(subjects: 206)
        #expect(largest == 206 * 48 + 160)
        #expect(largest <= 12_500)
        #expect(Institute.Repository.Policy.Caller.Wave.Capacity.requirement(subjects: 1) == 208)

        // Negative control: the acceptance predicate is untouched — a
        // pool one request short still refuses.
        let short = Institute.Repository.Policy.Caller.Wave.Capacity(
            remaining: largest - 1,
            required: largest,
            resetAt: 1_787_000_000
        )
        #expect(!short.accepted)
        let exact = Institute.Repository.Policy.Caller.Wave.Capacity(
            remaining: largest,
            required: largest,
            resetAt: 1_787_000_000
        )
        #expect(exact.accepted)
    }

    @Test
    func emptyOrganizationEnumerationRefusesThePopulation() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(
            ruleset: canonical,
            emptyRepositories: true
        )

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.enumerate(
                client: client,
                fleet: try fleet(organizations: ["swift-primitives"])
            )
        }
    }

    @Test
    func missingCallerRefusesThePopulation() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(
            ruleset: canonical,
            callerAbsent: true
        )

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.enumerate(
                client: client,
                fleet: try fleet(organizations: ["swift-primitives"])
            )
        }
    }

    @Test
    func manifestHeadRaceRefusesThePopulation() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        await client.setMoveHeadAfterManifestRead()

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.enumerate(
                client: client,
                fleet: try fleet(organizations: ["swift-primitives"])
            )
        }
    }

    @Test
    func recensusRequiresTheExactOriginalPopulationAndEvidenceSet() throws {
        let evidence = try recensusEvidence()
        let receipt = try Institute.Repository.Policy.Caller.Wave.recensus(
            original: evidence.original,
            current: evidence.current,
            evidence: recensusInput(evidence)
        )
        let allMatch = receipt.observations.allSatisfy { $0.matches }

        #expect(receipt.accepted)
        #expect(receipt.originalPopulation.subjectDigest == receipt.currentPopulation.subjectDigest)
        #expect(allMatch)
    }

    @Test
    func recensusRefusesOneMissingClosureFromANonemptyFleet() throws {
        let evidence = try recensusEvidence()
        let receipt = try Institute.Repository.Policy.Caller.Wave.recensus(
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
    func recensusRefusesAnEqualSizedSubstitutedPopulation() throws {
        let evidence = try recensusEvidence()
        let retained = try #require(evidence.current.subjects.first)
        let substituted = Institute.Repository.Policy.Caller.Wave.Subject(
            repository: "swift-primitives/c",
            repositoryID: 3,
            head: "new-head-2",
            manifest: .init(kind: "file", blob: "manifest-2"),
            caller: .init(blob: "new-blob-2", bytes: terminalCaller)
        )
        let current = Institute.Repository.Policy.Caller.Wave.Population(
            organizations: ["swift-primitives"],
            examined: 2,
            repositoryCounts: ["swift-primitives": 2],
            repositories: [retained.repository, substituted.repository],
            excluded: [:],
            subjects: [retained, substituted]
        )

        let receipt = try Institute.Repository.Policy.Caller.Wave.recensus(
            original: evidence.original,
            current: current,
            evidence: recensusInput(evidence)
        )

        #expect(!receipt.accepted)
    }

    @Test
    func appliesForwardCommitAndRestoresRuleset() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        var events: [Institute.Repository.Policy.Caller.Wave.Event] = []
        let receipt = try await Institute.Repository.Policy.Caller.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { events.append($0) }
        )

        #expect(receipt.changed)
        #expect(receipt.callerChanged)
        #expect(!receipt.rulesetChanged)
        #expect(receipt.oldHead == "old-head")
        #expect(receipt.newHead == "new-head")
        #expect(receipt.bypassClosed)
        #expect(recovery.caller.bytes == [Byte](utf8: "old\n"))
        #expect(recovery.rollbackHead == "old-head")
        #expect(recovery.ruleset?.id == 7)
        #expect(events.map(\.phase) == ["window-opening", "applied"])
        #expect(await client.replacements() == 2)
    }

    /// GitHub may serve stale ref reads for several seconds after a
    /// successful move (wave run 31830484954: eleven organizations
    /// aborted at their second subject while every sampled repository
    /// already sat at its created commit). A head that converges within
    /// the bounded backoff verifies; the transaction completes exactly
    /// as an immediately consistent one does.
    @Test
    func applyVerificationToleratesAStaleHeadReadAfterASuccessfulMove() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        await client.setStaleHeadReadsAfterMove(2)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        var events: [Institute.Repository.Policy.Caller.Wave.Event] = []

        let receipt = try await Institute.Repository.Policy.Caller.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { events.append($0) }
        )

        #expect(receipt.callerChanged)
        #expect(receipt.oldHead == "old-head")
        #expect(receipt.newHead == "new-head")
        #expect(receipt.bypassClosed)
        #expect(events.map(\.phase) == ["window-opening", "applied"])
        // The two stale reads cost exactly two backoff pauses.
        #expect(await client.pauses() == [1, 2])
    }

    /// The refusal is preserved: a head that never converges exhausts
    /// the bounded backoff and still throws the typed verification
    /// error, with the bypass closed on the way out.
    @Test
    func applyVerificationStillRefusesAHeadThatNeverConverges() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        await client.setStaleHeadReadsAfterMove(99)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        // Bounded: exactly the four backoff attempts, no unbounded poll.
        #expect(await client.pauses() == [1, 2, 3, 4])
    }

    @Test
    func createsMissingRulesetEvenWhenCallerIsAlreadyTerminal() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(
            ruleset: canonical,
            rulesetAbsent: true
        )
        await client.setCaller(bytes: [Byte](utf8: "new\n"), blob: "new-blob")
        let request = request(canonical: canonical, expectedBlob: "new-blob")
        let recovery = try await preflight(client: client, request: request)
        var events: [Institute.Repository.Policy.Caller.Wave.Event] = []

        let receipt = try await Institute.Repository.Policy.Caller.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { events.append($0) }
        )

        #expect(receipt.changed)
        #expect(!receipt.callerChanged)
        #expect(receipt.rulesetChanged)
        #expect(receipt.newHead == "old-head")
        #expect(recovery.priorRuleset == nil)
        #expect(recovery.ruleset == nil)
        #expect(events.map(\.phase) == ["ruleset-converged", "already-terminal"])
        #expect(await client.creations() == 1)
        #expect(await client.replacements() == 0)
    }

    @Test
    func movedHeadRefusesBeforeWindow() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setHead("other-head")

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 0)
    }

    @Test
    func movedBlobRefusesBeforeWindow() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setBlob("other-blob")

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 0)
    }

    @Test
    func noncanonicalRulesetConvergesBeforeWindow() async throws {
        let canonical = try ruleset()
        let divergent = try ruleset(enforcement: "disabled")
        let client = CallerWaveMockClient(ruleset: divergent)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        var events: [Institute.Repository.Policy.Caller.Wave.Event] = []

        let receipt = try await Institute.Repository.Policy.Caller.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { events.append($0) }
        )
        let divergentNormalized = try Institute.Repository.Policy.Caller.Wave.RulesetSnapshot.normalized(
            divergent
        )
        let canonicalNormalized = try Institute.Repository.Policy.Caller.Wave.RulesetSnapshot.normalized(
            canonical
        )

        #expect(receipt.callerChanged)
        #expect(receipt.rulesetChanged)
        #expect(recovery.priorRuleset?.restore == divergentNormalized)
        #expect(recovery.ruleset?.restore == divergentNormalized)
        #expect(receipt.rulesetChanged)
        #expect(canonicalNormalized != divergentNormalized)
        #expect(events.map(\.phase) == ["ruleset-converged", "window-opening", "applied"])
        #expect(await client.replacements() == 3)
    }

    @Test
    func failedRulesetConvergenceRestoresThePriorContract() async throws {
        let canonical = try ruleset()
        let divergent = try ruleset(enforcement: "disabled")
        let client = CallerWaveMockClient(ruleset: divergent)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setConvergenceFailure(persistent: true)

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }

        let restored = try await client.ruleset("swift-institute/example", id: 7)
        let restoredNormalized = try Institute.Repository.Policy.Caller.Wave.RulesetSnapshot.normalized(
            restored
        )
        let divergentNormalized = try Institute.Repository.Policy.Caller.Wave.RulesetSnapshot.normalized(
            divergent
        )
        #expect(await client.replacements() == 0)
        #expect(restoredNormalized == divergentNormalized)
    }

    @Test
    func failedMoveRestoresRuleset() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setMoveFailure()

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 2)
    }

    @Test
    func concurrentHeadMovementInsideWindowRefusesAndRestores() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setMoveHeadOnOpen()

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 2)
    }

    @Test
    func failedRestorationSurfacesCombinedFailure() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setMoveFailure()
        await client.setRestorationFailure()

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }
        #expect(await client.replacements() == 1)
    }

    @Test
    func openingAppliedThenResponseLostIsReconciledAndClosed() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setOpeningResponseLost()

        let receipt = try await Institute.Repository.Policy.Caller.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { _ in }
        )

        #expect(receipt.bypassClosed)
        #expect(!(await client.bypassOpen(integrationID: request.integrationID)))
        #expect(await client.replacements() == 2)
    }

    @Test
    func closingAppliedThenResponseLostIsReconciled() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setClosingResponseLost()

        let receipt = try await Institute.Repository.Policy.Caller.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { _ in }
        )

        #expect(receipt.bypassClosed)
        #expect(!(await client.bypassOpen(integrationID: request.integrationID)))
        #expect(await client.replacements() == 2)
    }

    @Test
    func transientRulesetReadFailureRetriesTheBoundedTransition() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setReadFailureAfterOpening()

        let receipt = try await Institute.Repository.Policy.Caller.Wave.run(
            client: client,
            request: request,
            recovery: recovery,
            record: { _ in }
        )

        #expect(receipt.bypassClosed)
        #expect(await client.replacements() == 3)
    }

    @Test
    func interruptionAfterOpeningStillClosesTheBypass() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        await client.setCommitFailure()

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { _ in }
            )
        }

        #expect(!(await client.bypassOpen(integrationID: request.integrationID)))
    }

    @Test
    func durablePreflightEvidenceClosesABypassAfterRunnerLoss() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let recovery = try await preflight(client: client, request: request)
        try await client.openBypass(integrationID: request.integrationID)

        let closure = try await Institute.Repository.Policy.Caller.Wave.close(
            client: client,
            recovery: recovery,
            caller: request.caller
        )

        #expect(closure.bypassClosed)
        #expect(closure.rulesetCanonical)
        #expect(!closure.accepted)
        #expect(!(await client.bypassOpen(integrationID: request.integrationID)))
    }

    @Test
    func preflightAcceptsTheExactTokenIssuanceAttestation() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let evidence = try attestation(fixture: "attestation-positive")

        let result = try await Institute.Repository.Policy.Caller.Wave.preflight(
            client: client,
            request: request,
            attestation: evidence.attestation,
            attestationDigest: evidence.digest
        )

        #expect(result.receipt.accepted)
        #expect(result.receipt.attestationDigest == evidence.digest)
        #expect(result.receipt.organization == "swift-institute")
        #expect(
            result.receipt.recoveryDigest
                == Institute.Repository.Policy.Caller.Wave.digest(
                    Institute.Repository.Policy.Caller.Wave.evidenceBytes(result.recovery)
                )
        )
    }

    @Test
    func preflightRefusesAMissingAttestationBeforeMeasurement() async throws {
        #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            _ = try Institute.Repository.Policy.Caller.Wave.Attestation.read(
                at: "/nonexistent/attestation.json"
            )
        }
    }

    @Test
    func preflightRefusesAMalformedAttestationBeforeMeasurement() async throws {
        let path = try #require(
            CallerWaveFoundation.fixturePath(forResource: "attestation-malformed", withExtension: "json")
        )

        #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            _ = try Institute.Repository.Policy.Caller.Wave.Attestation.read(at: path)
        }
    }

    /// `attestation-missing-workflows` is the fifth negative control,
    /// carrying exactly the two grants the pre-fix wave minted: an App
    /// token without `workflows: write` cannot rewrite a workflow file
    /// (run 31826746776), so its attestation must refuse at preflight.
    @Test(arguments: [
        "attestation-missing-contents",
        "attestation-missing-administration",
        "attestation-missing-workflows",
    ])
    func preflightRefusesAnAttestationWithoutTheRequiredWriteGrant(
        fixture: String
    ) async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let evidence = try attestation(fixture: fixture)

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.preflight(
                client: client,
                request: request,
                attestation: evidence.attestation,
                attestationDigest: evidence.digest
            )
        }
        #expect(await client.replacements() == 0)
    }

    @Test
    func preflightRefusesAnAttestationScopeThatDoesNotCoverTheSubject() async throws {
        let canonical = try ruleset()
        let client = CallerWaveMockClient(ruleset: canonical)
        let request = request(canonical: canonical)
        let evidence = try attestation(fixture: "attestation-foreign-scope")

        await #expect(throws: Institute.Repository.Policy.Caller.Wave.Error.self) {
            try await Institute.Repository.Policy.Caller.Wave.preflight(
                client: client,
                request: request,
                attestation: evidence.attestation,
                attestationDigest: evidence.digest
            )
        }
        #expect(await client.replacements() == 0)
    }

    @Test
    func repositoryPaginationFollowsLinksEvenAfterAShortPage() async throws {
        let client = Institute.Repository.Policy.Command.Client(
            delaySeconds: 0,
            execute: { _, path, _ in
                if path.hasPrefix("/orgs/swift-primitives/repos") {
                    if path.hasSuffix("page=1") {
                        return Self.response(
                            json: [Self.remoteRepository(id: 1, name: "a")],
                            headers: [
                                "link": "<https://api.github.test/orgs/swift-primitives/repos?"
                                    + "type=public&per_page=100&page=2>; rel=\"next\""
                            ]
                        )
                    }
                    return Self.response(
                        json: [Self.remoteRepository(id: 2, name: "b")]
                    )
                }
                return Self.response(json: ["public_repos": 2])
            }
        )

        let listing = try await client.waveRepositories(
            organization: "swift-primitives"
        )

        #expect(listing.expected == 2)
        #expect(
            listing.repositories.map(\.fullName) == ["swift-primitives/a", "swift-primitives/b"]
        )
    }

    @Test
    func repositoryPaginationRejectsADroppedMiddlePage() async throws {
        let client = Institute.Repository.Policy.Command.Client(
            delaySeconds: 0,
            execute: { _, path, _ in
                if path == "/orgs/swift-primitives" {
                    return Self.response(json: ["public_repos": 2])
                }
                return Self.response(
                    json: [Self.remoteRepository(id: 1, name: "a")],
                    headers: [
                        "link": "<https://api.github.test/orgs/swift-primitives/repos?"
                            + "type=public&per_page=100&page=3>; rel=\"next\""
                    ]
                )
            }
        )

        await #expect(throws: Institute.Repository.Policy.Client.Error.self) {
            try await client.waveRepositories(organization: "swift-primitives")
        }
    }

    @Test
    func repositoryPaginationRejectsADuplicatedPage() async throws {
        let client = Institute.Repository.Policy.Command.Client(
            delaySeconds: 0,
            execute: { _, path, _ in
                if path == "/orgs/swift-primitives" {
                    return Self.response(json: ["public_repos": 2])
                }
                let headers =
                    path.hasSuffix("page=1")
                    ? [
                        "link": "<https://api.github.test/orgs/swift-primitives/repos?"
                            + "type=public&per_page=100&page=2>; rel=\"next\""
                    ] : [:]
                return Self.response(
                    json: [Self.remoteRepository(id: 1, name: "a")],
                    headers: headers
                )
            }
        )

        await #expect(throws: Institute.Repository.Policy.Client.Error.self) {
            try await client.waveRepositories(organization: "swift-primitives")
        }
    }

    @Test
    func capacityRecordsWhetherTheCompleteWaveFits() async throws {
        for (remaining, required, accepted) in [(100, 80, true), (80, 81, false)] {
            let client = Institute.Repository.Policy.Command.Client(
                delaySeconds: 0,
                execute: { _, _, _ in
                    Self.response(
                        json: [
                            "resources": [
                                "core": ["remaining": remaining, "reset": 1_787_000_000]
                            ]
                        ]
                    )
                }
            )

            let capacity = try await client.capacity(requiredRequests: required)

            #expect(capacity.remaining == remaining)
            #expect(capacity.required == required)
            #expect(capacity.accepted == accepted)
        }
    }

    @Test(arguments: [429, 503])
    func retryableHTTPStatusIsRetried(status: Int) async throws {
        let counter = CallerWaveHTTPAttemptCounter()
        let client = Institute.Repository.Policy.Command.Client(
            maximumAttempts: 2,
            delaySeconds: 0,
            execute: { _, path, _ in
                if await counter.next() == 1 {
                    return Self.response(
                        json: ["message": "retry"],
                        status: status,
                        headers: ["retry-after": "0"]
                    )
                }
                if path.hasPrefix("/orgs/swift-primitives/repos") {
                    return Self.response(
                        json: [Self.remoteRepository(id: 1, name: "a")]
                    )
                }
                return Self.response(json: ["public_repos": 1])
            }
        )

        let listing = try await client.waveRepositories(organization: "swift-primitives")
        #expect(listing.repositories.count == 1)
        #expect(await counter.count() == 4)
    }

    @Test
    func transportFailureIsRetried() async throws {
        let counter = CallerWaveHTTPAttemptCounter()
        let client = Institute.Repository.Policy.Command.Client(
            maximumAttempts: 2,
            delaySeconds: 0,
            execute: {
                (
                    _,
                    path,
                    _
                ) async throws(Institute.GitHub.Transport.Error)
                    -> Institute.GitHub.Transport.Response in
                if await counter.next() == 1 {
                    throw Institute.GitHub.Transport.Error.spawn("injected transport failure")
                }
                if path.hasPrefix("/orgs/swift-primitives/repos") {
                    return Self.response(
                        json: [Self.remoteRepository(id: 1, name: "a")]
                    )
                }
                return Self.response(json: ["public_repos": 1])
            }
        )

        let listing = try await client.waveRepositories(organization: "swift-primitives")
        #expect(listing.repositories.count == 1)
        #expect(await counter.count() == 4)
    }

    private func request(
        canonical: [Byte],
        expectedBlob: String = "old-blob"
    ) -> Institute.Repository.Policy.Caller.Wave.Request {
        .init(
            repository: "swift-institute/example",
            expectedRepositoryID: 1,
            expectedHead: "old-head",
            expectedManifest: .init(kind: "file", blob: "manifest-blob"),
            expectedBlob: expectedBlob,
            caller: [Byte](utf8: "new\n"),
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
            commitMessage: "Adopt terminal caller [skip ci]"
        )
    }

    private func preflight(
        client: CallerWaveMockClient,
        request: Institute.Repository.Policy.Caller.Wave.Request
    ) async throws -> Institute.Repository.Policy.Caller.Wave.Recovery {
        let evidence = try attestation(fixture: "attestation-positive")
        let result = try await Institute.Repository.Policy.Caller.Wave.preflight(
            client: client,
            request: request,
            attestation: evidence.attestation,
            attestationDigest: evidence.digest
        )
        return result.recovery
    }

    private func attestation(
        fixture: String
    ) throws -> (attestation: Institute.Repository.Policy.Caller.Wave.Attestation, digest: String) {
        let path = try #require(CallerWaveFoundation.fixturePath(forResource: fixture, withExtension: "json"))
        return try Institute.Repository.Policy.Caller.Wave.Attestation.read(at: path)
    }

    private func recensusEvidence() throws -> (
        original: Institute.Repository.Policy.Caller.Wave.Population,
        current: Institute.Repository.Policy.Caller.Wave.Population,
        receipts: [Institute.Repository.Policy.Caller.Wave.Receipt],
        events: [Institute.Repository.Policy.Caller.Wave.Event],
        closures: [Institute.Repository.Policy.Caller.Wave.Closure]
    ) {
        let repositories = ["swift-primitives/a", "swift-primitives/b"]
        let originalSubjects = repositories.enumerated().map { offset, repository in
            Institute.Repository.Policy.Caller.Wave.Subject(
                repository: repository,
                repositoryID: Int64(offset + 1),
                head: "old-head-\(offset)",
                manifest: .init(kind: "file", blob: "manifest-\(offset)"),
                caller: .init(blob: "old-blob-\(offset)", bytes: [Byte](utf8: "old\n"))
            )
        }
        let currentSubjects = repositories.enumerated().map { offset, repository in
            Institute.Repository.Policy.Caller.Wave.Subject(
                repository: repository,
                repositoryID: Int64(offset + 1),
                head: "new-head-\(offset)",
                manifest: .init(kind: "file", blob: "manifest-\(offset)"),
                caller: .init(blob: "new-blob-\(offset)", bytes: terminalCaller)
            )
        }
        let original = Institute.Repository.Policy.Caller.Wave.Population(
            organizations: ["swift-primitives"],
            examined: 2,
            repositoryCounts: ["swift-primitives": 2],
            repositories: repositories,
            excluded: [:],
            subjects: originalSubjects
        )
        let current = Institute.Repository.Policy.Caller.Wave.Population(
            organizations: ["swift-primitives"],
            examined: 2,
            repositoryCounts: ["swift-primitives": 2],
            repositories: repositories,
            excluded: [:],
            subjects: currentSubjects
        )
        let receipts = repositories.indices.map { index in
            Institute.Repository.Policy.Caller.Wave.Receipt(
                repository: repositories[index],
                oldHead: originalSubjects[index].head,
                newHead: currentSubjects[index].head,
                oldBlob: originalSubjects[index].caller.blob,
                newBlob: currentSubjects[index].caller.blob,
                ruleset: 7,
                callerChanged: true,
                rulesetChanged: false,
                bypassClosed: true,
                population: original.commitment,
                policyDigest: policyDigest,
                policySource: policySource
            )
        }
        let events = repositories.indices.map { index in
            Institute.Repository.Policy.Caller.Wave.Event(
                phase: "applied",
                repository: repositories[index],
                oldHead: originalSubjects[index].head,
                newHead: currentSubjects[index].head,
                oldBlob: originalSubjects[index].caller.blob,
                newBlob: currentSubjects[index].caller.blob,
                ruleset: 7,
                bypassClosed: true,
                populationDigest: original.commitment.stateDigest,
                policyDigest: policyDigest,
                policySource: policySource
            )
        }
        let closures = repositories.indices.map { index in
            Institute.Repository.Policy.Caller.Wave.Closure(
                repository: repositories[index],
                head: currentSubjects[index].head,
                blob: currentSubjects[index].caller.blob,
                callerDigest: terminalCallerDigest,
                callerMatches: true,
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
            original: Institute.Repository.Policy.Caller.Wave.Population,
            current: Institute.Repository.Policy.Caller.Wave.Population,
            receipts: [Institute.Repository.Policy.Caller.Wave.Receipt],
            events: [Institute.Repository.Policy.Caller.Wave.Event],
            closures: [Institute.Repository.Policy.Caller.Wave.Closure]
        ),
        closures: [Institute.Repository.Policy.Caller.Wave.Closure]? = nil
    ) -> Institute.Repository.Policy.Caller.Wave.Recensus.Evidence {
        .init(
            caller: terminalCaller,
            receipts: evidence.receipts,
            events: evidence.events,
            closures: closures ?? evidence.closures,
            policyDigest: policyDigest,
            policySource: policySource
        )
    }

    private var terminalCaller: [Byte] { [Byte](utf8: "terminal\n") }
    private var terminalCallerDigest: String {
        "770b1fadc4019d4de6b2fd32561beaa2c8cffa7837f43c85cbeff1e211c60702"
    }
    private var policyDigest: String { String(repeating: "b", count: 64) }
    private var policySource: String { String(repeating: "a", count: 40) }

    private static func remoteRepository(id: Int64, name: String) -> [String: Any] {
        [
            "id": id,
            "name": name,
            "full_name": "swift-primitives/\(name)",
            "visibility": "public",
            "archived": false,
            "disabled": false,
            "fork": false,
            "size": 1,
        ]
    }

    private static func response(
        json: Any,
        status: Int = 200,
        headers: [String: String] = [:]
    ) -> Institute.GitHub.Transport.Response {
        guard let data = try? CallerWaveFoundation.jsonBytes(withJSONObject: json) else {
            preconditionFailure("literal test payload failed to encode")
        }
        return .init(status: status, headers: headers, body: data)
    }

    private func ruleset(enforcement: String = "active") throws -> [Byte] {
        try CallerWaveFoundation.sortedKeysJSONBytes(
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
        return try CallerWaveFoundation.decode(
            Institute.Repository.Policy.Fleet.self,
            fromJSONObject: ["schemaVersion": 1, "organizations": values]
        )
    }
}
