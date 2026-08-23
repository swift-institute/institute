public import Institute_Model


extension Institute.Repository.Policy.Caller.Wave {
    public static func preflight<C: Client>(
        client: C,
        request: Request,
        attestation: Attestation,
        attestationDigest: String
    ) async throws(Error) -> (recovery: Recovery, receipt: Preflight) {
        guard request.population.repositories > 0, request.population.subjects > 0 else {
            throw .population("caller-wave preflight received an empty population commitment")
        }
        guard request.policySource.count == 40, request.policyDigest.count == 64 else {
            throw .verification("caller-wave policy source or digest is not exact")
        }
        let components = request.repository.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2, !components[0].isEmpty, !components[1].isEmpty else {
            throw .invalidRepository("invalid repository coordinate \(request.repository)")
        }
        try attestation.authorize(repository: request.repository)

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
        let caller = try await guardedCaller(client: client, request: request, head: head)
        let references = try await protectedMainReferences(client: client, request.repository)
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
            caller: caller,
            callerDigest: request.callerDigest,
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
            recoveryDigest: digest(try evidenceData(recovery)),
            attestationDigest: attestationDigest,
            accepted: true
        )
        return (recovery, receipt)
    }

    static func validate(
        repository: Repository,
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

    static func protectedMainReferences<C: Client>(
        client: C,
        _ repository: String
    ) async throws(Error) -> [RulesetReference] {
        let references = try await calling { try await client.rulesets(repository) }
            .filter { $0.name == "Institute protected main" }
        guard references.count <= 1 else {
            throw .ruleset(
                "\(repository): found \(references.count) Institute protected main rulesets"
            )
        }
        return references
    }
}
