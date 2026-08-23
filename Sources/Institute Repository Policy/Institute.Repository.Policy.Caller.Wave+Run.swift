public import Institute_Model
public import Byte_Primitives

extension Institute.Repository.Policy.Caller.Wave {
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
        let oldCaller = try await guardedCaller(client: client, request: request, head: oldHead)
        let oldBlob = oldCaller.blob
        let newBlob = try await calling {
            try await client.createBlob(request.repository, content: request.caller)
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
                    oldBlob: oldBlob,
                    ruleset: prepared.snapshot.id,
                    bypassClosed: true
                ),
                through: record
            )
        }
        if oldBlob == newBlob {
            try await closeBypass(
                client: client,
                repository: request.repository,
                rulesetID: prepared.snapshot.id,
                integrationID: request.integrationID
            )
            let receipt = Receipt(
                repository: request.repository,
                oldHead: oldHead,
                newHead: oldHead,
                oldBlob: oldBlob,
                newBlob: oldBlob,
                ruleset: prepared.snapshot.id,
                callerChanged: false,
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
                    oldBlob: oldBlob,
                    newBlob: oldBlob,
                    ruleset: prepared.snapshot.id,
                    bypassClosed: true
                ),
                through: record
            )
            return receipt
        }

        let snapshot = prepared.snapshot
        do throws(Error) {
            try recording(
                event(
                    phase: "window-opening",
                    request: request,
                    oldHead: oldHead,
                    oldBlob: oldBlob,
                    ruleset: snapshot.id,
                    bypassClosed: false
                ),
                through: record
            )
            try await transitionRuleset(
                client: client,
                snapshot: snapshot,
                from: snapshot.restore,
                to: snapshot.opened,
                phase: "opening"
            )
            _ = try await guardedHead(client: client, request: request)
            _ = try await guardedCaller(client: client, request: request, head: oldHead)
            let candidateHead = try await calling {
                try await client.createCommit(
                    request.repository,
                    parent: oldHead,
                    blob: newBlob,
                    message: request.commitMessage
                )
            }
            _ = try await guardedHead(client: client, request: request)
            try await calling {
                try await client.moveMain(request.repository, to: candidateHead)
            }
            let verifiedHead = try await convergedHead(
                client: client,
                repository: request.repository,
                expected: candidateHead
            )
            let verifiedCaller = try await calling {
                try await client.callerSource(request.repository, head: verifiedHead)
            }
            guard verifiedCaller.blob == newBlob, verifiedCaller.bytes == request.caller else {
                throw .verification(
                    "\(request.repository): terminal caller bytes did not verify after commit"
                )
            }
            try await closeBypass(
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
                    oldBlob: oldBlob,
                    newBlob: verifiedCaller.blob,
                    ruleset: snapshot.id,
                    bypassClosed: true
                ),
                through: record
            )
            return Receipt(
                repository: request.repository,
                oldHead: oldHead,
                newHead: verifiedHead,
                oldBlob: oldBlob,
                newBlob: verifiedCaller.blob,
                ruleset: snapshot.id,
                callerChanged: true,
                rulesetChanged: prepared.changed,
                bypassClosed: true,
                population: request.population,
                policyDigest: request.policyDigest,
                policySource: request.policySource
            )
        } catch let primary {
            do throws(Error) {
                try await closeBypass(
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
        let live = try await calling {
            try await client.ruleset(snapshot.repository, id: snapshot.id)
        }
        try await transitionRuleset(
            client: client,
            snapshot: snapshot,
            from: live,
            to: snapshot.restore,
            phase: "restoration"
        )
    }

    static func closeBypass<C: Client>(
        client: C,
        repository: String,
        rulesetID: Int64,
        integrationID: Int64
    ) async throws(Error) {
        var live = try await calling { try await client.ruleset(repository, id: rulesetID) }
        for attempt in 1...4 {
            guard RulesetSnapshot.containsIntegration(live, integrationID: integrationID) else {
                return
            }
            let closed = try RulesetSnapshot.removingIntegration(
                live,
                integrationID: integrationID
            )
            do throws(Error) {
                try await calling {
                    try await client.replaceRuleset(repository, id: rulesetID, payload: closed)
                }
            } catch let mutation {
                do throws(Error) {
                    live = try await calling { try await client.ruleset(repository, id: rulesetID) }
                } catch {
                    if attempt == 4 { throw mutation }
                    await client.pause(attempt: attempt)
                    continue
                }
                if !RulesetSnapshot.containsIntegration(live, integrationID: integrationID) {
                    return
                }
                if attempt == 4 { throw mutation }
                await client.pause(attempt: attempt)
                continue
            }
            live = try await calling { try await client.ruleset(repository, id: rulesetID) }
            if !RulesetSnapshot.containsIntegration(live, integrationID: integrationID) {
                return
            }
            if attempt < 4 { await client.pause(attempt: attempt) }
        }
        throw .ruleset("\(repository): integration bypass could not be verified closed")
    }

    /// The post-move head verification, tolerant of GitHub's
    /// read-after-write lag: a successful ref move may be followed by a
    /// stale read for several seconds (wave run 31830484954: eleven
    /// organizations aborted at their second subject on the immediate
    /// read-back while every sampled repository already sat at its
    /// created commit). The head is re-read with the client's bounded
    /// backoff — 2+4+8+16 seconds, ~30 seconds total — and a head that
    /// never converges still refuses with the same typed verification
    /// error. This is the only read-after-write in the apply path that
    /// keys on a MOVING ref: the subsequent caller-bytes check reads
    /// content at the verified immutable commit, and the ruleset loops
    /// already re-read with backoff.
    static func convergedHead<C: Client>(
        client: C,
        repository: String,
        expected: String
    ) async throws(Error) -> String {
        var head = try await calling { try await client.head(repository) }
        for attempt in 1...4 where head != expected {
            await client.pause(attempt: attempt)
            head = try await calling { try await client.head(repository) }
        }
        guard head == expected else {
            throw .verification(
                "\(repository): main did not move to created commit \(expected)"
            )
        }
        return head
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

    static func guardedCaller<C: Client>(
        client: C,
        request: Request,
        head: String
    ) async throws(Error) -> CallerSource {
        let actual = try await calling {
            try await client.callerSource(request.repository, head: head)
        }
        guard actual.blob == request.expectedBlob else {
            throw .movedBlob(
                repository: request.repository,
                expected: request.expectedBlob,
                actual: actual.blob
            )
        }
        return actual
    }

    static func calling<T>(
        _ body: () async throws -> T
    ) async throws(Error) -> T {
        do {
            return try await body()
        } catch let error as Institute.Repository.Policy.Client.Error {
            throw .client(error)
        } catch {
            throw .verification("unexpected client refusal: \(error)")
        }
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
            recovery.caller.blob == request.expectedBlob,
            recovery.callerDigest == request.callerDigest,
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
    ) async throws(Error) -> PreparedRuleset {
        let references = try await protectedMainReferences(client: client, request.repository)
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
            try await closeBypass(
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
            return PreparedRuleset(
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
            try await transitionRuleset(
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
                try await transitionRuleset(
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
        return PreparedRuleset(snapshot: intended, changed: true)
    }

    private static func createCanonicalRuleset<C: Client>(
        client: C,
        request: Request
    ) async throws(Error) -> PreparedRuleset {
        let id: Int64
        do throws(Error) {
            id = try await calling {
                try await client.createRuleset(
                    request.repository,
                    payload: request.canonicalRuleset
                )
            }
        } catch let mutation {
            let references = try await protectedMainReferences(client: client, request.repository)
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
        return PreparedRuleset(snapshot: snapshot, changed: true)
    }

    // Internal, not private: the uniformity wave family reuses this exact
    // debugged bounded transition rather than growing a second copy.
    static func transitionRuleset<C: Client>(
        client: C,
        snapshot: RulesetSnapshot,
        from previous: [Byte],
        to intended: [Byte],
        phase: String
    ) async throws(Error) {
        var last: Institute.Repository.Policy.Caller.Wave.Error?
        for attempt in 1...4 {
            do throws(Error) {
                try await calling {
                    try await client.replaceRuleset(
                        snapshot.repository,
                        id: snapshot.id,
                        payload: intended
                    )
                }
            } catch let mutation {
                last = mutation
            }
            let live: [Byte]
            do throws(Error) {
                live = try await calling {
                    try await client.ruleset(snapshot.repository, id: snapshot.id)
                }
            } catch let readback {
                last = readback
                if attempt < 4 {
                    await client.pause(attempt: attempt)
                    continue
                }
                throw readback
            }
            if RulesetSnapshot.matches(live, expected: intended) { return }
            guard RulesetSnapshot.matches(live, expected: previous) else {
                throw .ruleset(
                    "\(snapshot.repository): ruleset entered unexpected state during \(phase)"
                )
            }
            if attempt < 4 {
                await client.pause(attempt: attempt)
            }
        }
        if let last { throw last }
        throw .ruleset("\(snapshot.repository): \(phase) did not reach its intended state")
    }

    private static func event(
        phase: String,
        request: Request,
        oldHead: String? = nil,
        newHead: String? = nil,
        oldBlob: String? = nil,
        newBlob: String? = nil,
        ruleset: Int64? = nil,
        bypassClosed: Bool? = nil
    ) -> Event {
        Event(
            phase: phase,
            repository: request.repository,
            oldHead: oldHead,
            newHead: newHead,
            oldBlob: oldBlob,
            newBlob: newBlob,
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
