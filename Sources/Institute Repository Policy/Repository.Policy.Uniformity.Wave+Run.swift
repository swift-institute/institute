
extension Repository.Policy.Uniformity.Wave {
    public static func run<C: Client>(
        client: C,
        request: Request,
        recovery: Recovery,
        record: (Event) throws -> Void
    ) async throws(Error) -> Receipt {
        try validate(recovery: recovery, request: request)
        let repository = try await calling { try await client.waveRepository(request.repository) }
        try validate(repository: repository, request: request)
        let oldHead = try await guardedHead(client: client, request: request)
        let manifest = try await calling {
            try await client.rootManifest(request.repository, head: oldHead)
        }
        guard manifest == request.expectedManifest else {
            throw .population("\(request.repository): root manifest moved after preflight")
        }
        let oldShape = try await guardedShape(client: client, request: request, head: oldHead)
        let newBlob = try await calling {
            try await client.createBlob(request.repository, content: request.payload)
        }
        let prepared = try await prepareRuleset(
            client: client,
            request: request,
            recovery: recovery
        )
        if prepared.changed {
            try recording(
                event(
                    phase: "ruleset-converged",
                    request: request,
                    oldHead: oldHead,
                    oldGitignore: oldShape.gitignore?.blob,
                    ruleset: prepared.snapshot.id,
                    bypassClosed: true
                ),
                through: record
            )
        }
        if oldShape.terminal(payload: request.payload) {
            try await Repository.Policy.Caller.Wave.closeBypass(
                client: client,
                repository: request.repository,
                rulesetID: prepared.snapshot.id,
                integrationID: request.integrationID
            )
            let receipt = Receipt(
                repository: request.repository,
                oldHead: oldHead,
                newHead: oldHead,
                oldGitignore: oldShape.gitignore?.blob,
                newGitignore: newBlob,
                deleted: [],
                ruleset: prepared.snapshot.id,
                shapeChanged: false,
                rulesetChanged: prepared.changed,
                bypassClosed: true,
                population: request.population,
                policyDigest: request.policyDigest,
                policySource: request.policySource
            )
            try recording(
                event(
                    phase: "already-terminal",
                    request: request,
                    oldHead: oldHead,
                    newHead: oldHead,
                    oldGitignore: oldShape.gitignore?.blob,
                    newGitignore: oldShape.gitignore?.blob,
                    deletions: [],
                    ruleset: prepared.snapshot.id,
                    bypassClosed: true
                ),
                through: record
            )
            return receipt
        }

        let deletions = oldShape.presentDeletions
        let snapshot = prepared.snapshot
        do throws(Error) {
            try recording(
                event(
                    phase: "window-opening",
                    request: request,
                    oldHead: oldHead,
                    oldGitignore: oldShape.gitignore?.blob,
                    deletions: deletions,
                    ruleset: snapshot.id,
                    bypassClosed: false
                ),
                through: record
            )
            try await Repository.Policy.Caller.Wave.transitionRuleset(
                client: client,
                snapshot: snapshot,
                from: snapshot.restore,
                to: snapshot.opened,
                phase: "opening"
            )
            _ = try await guardedHead(client: client, request: request)
            _ = try await guardedShape(client: client, request: request, head: oldHead)
            let candidateHead = try await calling {
                try await client.createShapeCommit(
                    request.repository,
                    parent: oldHead,
                    gitignoreBlob: newBlob,
                    deletions: deletions,
                    message: request.commitMessage
                )
            }
            _ = try await guardedHead(client: client, request: request)
            try await calling {
                try await client.moveMain(request.repository, to: candidateHead)
            }
            let verifiedHead = try await Repository.Policy.Caller.Wave.convergedHead(
                client: client,
                repository: request.repository,
                expected: candidateHead
            )
            let verifiedShape = try await shape(
                client: client,
                repository: request.repository,
                head: verifiedHead
            )
            guard let verified = verifiedShape.gitignore,
                verified.blob == newBlob,
                verified.bytes == request.payload,
                Repository.Policy.Caller.Wave.digest(verified.bytes) == request.payloadDigest
            else {
                throw .verification(
                    "\(request.repository): shape policy bytes did not verify after commit"
                )
            }
            guard verifiedShape.presentDeletions.isEmpty else {
                throw .verification(
                    "\(request.repository): retired files still present after commit: "
                        + verifiedShape.presentDeletions.joined(separator: ", ")
                )
            }
            try await Repository.Policy.Caller.Wave.closeBypass(
                client: client,
                repository: request.repository,
                rulesetID: snapshot.id,
                integrationID: request.integrationID
            )
            let closed = try await calling {
                try await client.ruleset(request.repository, id: snapshot.id)
            }
            guard snapshot.verifiesClosed(closed) else {
                throw .ruleset(
                    "\(request.repository): protected-main policy moved during transaction"
                )
            }
            try recording(
                event(
                    phase: "applied",
                    request: request,
                    oldHead: oldHead,
                    newHead: verifiedHead,
                    oldGitignore: oldShape.gitignore?.blob,
                    newGitignore: verified.blob,
                    deletions: deletions,
                    ruleset: snapshot.id,
                    bypassClosed: true
                ),
                through: record
            )
            return Receipt(
                repository: request.repository,
                oldHead: oldHead,
                newHead: verifiedHead,
                oldGitignore: oldShape.gitignore?.blob,
                newGitignore: verified.blob,
                deleted: deletions,
                ruleset: snapshot.id,
                shapeChanged: true,
                rulesetChanged: prepared.changed,
                bypassClosed: true,
                population: request.population,
                policyDigest: request.policyDigest,
                policySource: request.policySource
            )
        } catch let primary {
            do throws(Error) {
                try await Repository.Policy.Caller.Wave.closeBypass(
                    client: client,
                    repository: request.repository,
                    rulesetID: snapshot.id,
                    integrationID: request.integrationID
                )
            } catch let closure {
                throw .restoration(primary: primary.description, restore: closure.description)
            }
            throw primary
        }
    }

    public static func restore<C: Client>(
        client: C,
        snapshot: RulesetSnapshot
    ) async throws(Error) {
        try await Repository.Policy.Caller.Wave.restore(client: client, snapshot: snapshot)
    }

    private static func validate(
        recovery: Recovery,
        request: Request
    ) throws(Error) {
        let canonical = try RulesetSnapshot.normalized(request.canonicalRuleset)
        guard recovery.repository == request.repository,
            recovery.repositoryID == request.expectedRepositoryID,
            recovery.rollbackHead == request.expectedHead,
            recovery.manifest == request.expectedManifest,
            recovery.shape == request.expectedShape,
            recovery.payloadDigest == request.payloadDigest,
            recovery.population == request.population,
            recovery.canonicalRuleset == canonical,
            recovery.integrationID == request.integrationID,
            recovery.policyDigest == request.policyDigest,
            recovery.policySource == request.policySource
        else {
            throw .verification("\(request.repository): recovery does not bind the apply request")
        }
    }

    private static func prepareRuleset<C: Client>(
        client: C,
        request: Request,
        recovery: Recovery
    ) async throws(Error) -> Repository.Policy.Caller.Wave.PreparedRuleset {
        let references = try await Repository.Policy.Caller.Wave.protectedMainReferences(
            client: client,
            request.repository
        )
        guard let reference = references.first else {
            guard recovery.priorRuleset == nil else {
                throw .ruleset("\(request.repository): preflight ruleset disappeared")
            }
            return try await createCanonicalRuleset(client: client, request: request)
        }
        if let prior = recovery.priorRuleset, prior.id != reference.id {
            throw .ruleset("\(request.repository): protected-main ruleset identity moved")
        }
        var live = try await calling {
            try await client.ruleset(request.repository, id: reference.id)
        }
        if RulesetSnapshot.containsIntegration(live, integrationID: request.integrationID) {
            try await Repository.Policy.Caller.Wave.closeBypass(
                client: client,
                repository: request.repository,
                rulesetID: reference.id,
                integrationID: request.integrationID
            )
            live = try await calling {
                try await client.ruleset(request.repository, id: reference.id)
            }
        }
        let canonical = try RulesetSnapshot.normalized(request.canonicalRuleset)
        if RulesetSnapshot.matches(live, expected: canonical) {
            let snapshot = try RulesetSnapshot(
                repository: request.repository,
                id: reference.id,
                live: live,
                canonical: canonical,
                integrationID: request.integrationID
            )
            return .init(
                snapshot: snapshot,
                changed: recovery.priorRuleset?.restore != canonical
            )
        }
        guard let prior = recovery.priorRuleset,
            RulesetSnapshot.matches(live, expected: prior.restore)
        else {
            throw .ruleset("\(request.repository): ruleset moved after preflight")
        }
        let intended = try RulesetSnapshot(
            repository: request.repository,
            id: reference.id,
            live: canonical,
            canonical: canonical,
            integrationID: request.integrationID
        )
        do throws(Error) {
            try await Repository.Policy.Caller.Wave.transitionRuleset(
                client: client,
                snapshot: intended,
                from: live,
                to: canonical,
                phase: "canonical convergence"
            )
        } catch let primary {
            do throws(Error) {
                let current = try await calling {
                    try await client.ruleset(request.repository, id: reference.id)
                }
                try await Repository.Policy.Caller.Wave.transitionRuleset(
                    client: client,
                    snapshot: prior,
                    from: current,
                    to: prior.restore,
                    phase: "convergence rollback"
                )
            } catch let restoreError {
                throw .restoration(
                    primary: primary.description,
                    restore: restoreError.description
                )
            }
            throw primary
        }
        return .init(snapshot: intended, changed: true)
    }

    private static func createCanonicalRuleset<C: Client>(
        client: C,
        request: Request
    ) async throws(Error) -> Repository.Policy.Caller.Wave.PreparedRuleset {
        let id: Int64
        do throws(Error) {
            id = try await calling {
                try await client.createRuleset(
                    request.repository,
                    payload: request.canonicalRuleset
                )
            }
        } catch let mutation {
            let references = try await Repository.Policy.Caller.Wave.protectedMainReferences(
                client: client,
                request.repository
            )
            guard let reconciled = references.first else { throw mutation }
            id = reconciled.id
        }
        let live = try await calling { try await client.ruleset(request.repository, id: id) }
        let canonical = try RulesetSnapshot.normalized(request.canonicalRuleset)
        guard RulesetSnapshot.matches(live, expected: canonical) else {
            throw .ruleset("\(request.repository): created ruleset is not canonical")
        }
        let snapshot = try RulesetSnapshot(
            repository: request.repository,
            id: id,
            live: live,
            canonical: canonical,
            integrationID: request.integrationID
        )
        return .init(snapshot: snapshot, changed: true)
    }

    private static func event(
        phase: String,
        request: Request,
        oldHead: String? = nil,
        newHead: String? = nil,
        oldGitignore: String? = nil,
        newGitignore: String? = nil,
        deletions: [String]? = nil,
        ruleset: Int64? = nil,
        bypassClosed: Bool? = nil
    ) -> Event {
        Event(
            phase: phase,
            repository: request.repository,
            oldHead: oldHead,
            newHead: newHead,
            oldGitignore: oldGitignore,
            newGitignore: newGitignore,
            deletions: deletions,
            ruleset: ruleset,
            bypassClosed: bypassClosed,
            populationDigest: request.population.stateDigest,
            policyDigest: request.policyDigest,
            policySource: request.policySource
        )
    }

    private static func recording(
        _ event: Event,
        through record: (Event) throws -> Void
    ) throws(Error) {
        do {
            try record(event)
        } catch {
            throw .journal("\(event.repository): could not append \(event.phase): \(error)")
        }
    }
}
