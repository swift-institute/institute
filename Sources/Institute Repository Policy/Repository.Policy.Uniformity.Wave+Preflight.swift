
extension Repository.Policy.Uniformity.Wave {
    public static func preflight<C: Client>(
        client: C,
        request: Request,
        attestation: Attestation,
        attestationDigest: String
    ) async throws(Error) -> (recovery: Recovery, receipt: Preflight) {
        guard request.population.repositories > 0, request.population.subjects > 0 else {
            throw .population("uniformity-wave preflight received an empty population commitment")
        }
        guard request.policySource.count == 40, request.policyDigest.count == 64 else {
            throw .verification("uniformity-wave policy source or digest is not exact")
        }
        guard request.payloadDigest == Payload.digest else {
            throw .verification(
                "\(request.repository): shape payload does not hash to the ratified digest"
            )
        }
        let components = request.repository.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            throw .invalidRepository("invalid repository coordinate \(request.repository)")
        }
        try authorize(attestation, repository: request.repository)

        let repository = try await calling {
            try await client.waveRepository(request.repository)
        }
        try validate(repository: repository, request: request)
        let head = try await guardedHead(client: client, request: request)
        let manifest = try await calling {
            try await client.rootManifest(request.repository, head: head)
        }
        guard manifest == request.expectedManifest else {
            throw .population("\(request.repository): root manifest moved before preflight")
        }
        let shape = try await guardedShape(client: client, request: request, head: head)
        let references = try await Repository.Policy.Caller.Wave.protectedMainReferences(
            client: client,
            request.repository
        )
        let prior: RulesetSnapshot?
        if let reference = references.first {
            let live = try await calling {
                try await client.ruleset(request.repository, id: reference.id)
            }
            guard
                !RulesetSnapshot.containsIntegration(
                    live,
                    integrationID: request.integrationID
                )
            else {
                throw .ruleset(
                    "\(request.repository): integration bypass was already open before preflight"
                )
            }
            prior = try RulesetSnapshot(
                repository: request.repository,
                id: reference.id,
                live: live,
                canonical: live,
                integrationID: request.integrationID
            )
        } else {
            prior = nil
        }
        let canonical = try RulesetSnapshot.normalized(request.canonicalRuleset)
        let verifiedRepository = try await calling {
            try await client.waveRepository(request.repository)
        }
        let verifiedHead = try await guardedHead(client: client, request: request)
        guard repository == verifiedRepository, head == verifiedHead else {
            throw .population("\(request.repository): preflight facts moved during measurement")
        }

        let recovery = Recovery(
            repository: request.repository,
            repositoryID: request.expectedRepositoryID,
            rollbackHead: head,
            manifest: request.expectedManifest,
            shape: shape,
            payloadDigest: request.payloadDigest,
            population: request.population,
            canonicalRuleset: canonical,
            integrationID: request.integrationID,
            policyDigest: request.policyDigest,
            policySource: request.policySource,
            priorRuleset: prior,
            ruleset: prior
        )
        let receipt = Preflight(
            organization: String(components[0]),
            repository: request.repository,
            population: request.population,
            recoveryDigest: Repository.Policy.Caller.Wave.digest(
                try Repository.Policy.Caller.Wave.evidenceData(recovery)
            ),
            attestationDigest: attestationDigest,
            accepted: true
        )
        return (recovery, receipt)
    }

    /// The uniformity wave writes plain content and never touches a
    /// workflow file, so its token must carry `contents: write` and
    /// `administration: write` and must NOT carry the `workflows`
    /// permission at all — a token that can rewrite workflow files is
    /// over-privileged for this transaction and preflight refuses it
    /// before any measurement.
    public static func authorize(
        _ attestation: Attestation,
        repository: String
    ) throws(Error) {
        let components = repository.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            throw .invalidRepository("invalid repository coordinate \(repository)")
        }
        guard !attestation.appClientID.isEmpty, !attestation.appSlug.isEmpty,
            attestation.installationID > 0, attestation.runID > 0
        else {
            throw .attestation(
                "\(repository): token issuance attestation identity is incomplete"
            )
        }
        guard attestation.permissions["contents"] == "write" else {
            throw .attestation(
                "\(repository): token issuance attestation does not grant contents: write"
            )
        }
        guard attestation.permissions["administration"] == "write" else {
            throw .attestation(
                "\(repository): token issuance attestation does not grant administration: write"
            )
        }
        guard attestation.permissions["workflows"] == nil else {
            throw .attestation(
                "\(repository): uniformity token must not carry the workflows permission"
            )
        }
        guard attestation.organization == String(components[0]),
            attestation.repositories.contains(String(components[1]))
        else {
            throw .attestation(
                "\(repository): token issuance attestation scope does not cover the subject"
            )
        }
    }

    static func validate(
        repository: Repository.Policy.Caller.Wave.Repository,
        request: Request
    ) throws(Error) {
        guard repository.id == request.expectedRepositoryID else {
            throw .population("\(request.repository): repository identity moved before preflight")
        }
        guard repository.visibility == "public", !repository.archived, !repository.disabled,
            repository.defaultBranch == "main"
        else {
            throw .invalidRepository("\(request.repository): not an active public main repository")
        }
    }

    static func guardedHead<C: Client>(
        client: C,
        request: Request
    ) async throws(Error) -> String {
        let actual = try await calling { try await client.head(request.repository) }
        guard actual == request.expectedHead else {
            throw .movedHead(
                repository: request.repository,
                expected: request.expectedHead,
                actual: actual
            )
        }
        return actual
    }

    static func guardedShape<C: Client>(
        client: C,
        request: Request,
        head: String
    ) async throws(Error) -> Shape {
        let actual = try await shape(client: client, repository: request.repository, head: head)
        guard actual == request.expectedShape else {
            throw .verification(
                "\(request.repository): repository shape moved from the committed census state"
            )
        }
        return actual
    }
}
