public import Institute_Model
public import Foundation

extension Institute.Repository.Policy.Caller.Wave {
    public static func close<C: Client>(
        client: C,
        recovery: Recovery,
        caller: Data
    ) async throws(Error) -> Closure {
        guard digest(caller) == recovery.callerDigest else {
            throw .verification("\(recovery.repository): closure caller digest moved")
        }
        let repository = try await calling {
            try await client.waveRepository(recovery.repository)
        }
        let head = try await calling { try await client.head(recovery.repository) }
        let manifest = try await calling {
            try await client.rootManifest(recovery.repository, head: head)
        }
        let source = try await calling {
            try await client.callerSourceIfPresent(recovery.repository, head: head)
        }
        let references = try await protectedMainReferences(client: client, recovery.repository)
        let rulesetID = references.first?.id
        if let rulesetID {
            try await closeBypass(
                client: client,
                repository: recovery.repository,
                rulesetID: rulesetID,
                integrationID: recovery.integrationID
            )
        }
        let finalRuleset: Data?
        if let rulesetID {
            finalRuleset = try await calling {
                try await client.ruleset(recovery.repository, id: rulesetID)
            }
        } else {
            finalRuleset = nil
        }
        let bypassClosed =
            finalRuleset.map {
                !RulesetSnapshot.containsIntegration($0, integrationID: recovery.integrationID)
            } ?? true
        let canonical =
            finalRuleset.map {
                RulesetSnapshot.matches($0, expected: recovery.canonicalRuleset)
            } ?? false
        let callerMatches =
            source?.bytes == caller
            && source.map { digest($0.bytes) } == recovery.callerDigest
        let subjectStable =
            repository.id == recovery.repositoryID
            && repository.visibility == "public"
            && !repository.archived
            && !repository.disabled
            && repository.defaultBranch == "main"
            && manifest == recovery.manifest
        return Closure(
            repository: recovery.repository,
            head: head,
            blob: source?.blob,
            callerDigest: source.map { digest($0.bytes) },
            callerMatches: callerMatches,
            subjectStable: subjectStable,
            ruleset: rulesetID,
            rulesetCanonical: canonical,
            bypassClosed: bypassClosed,
            population: recovery.population,
            policyDigest: recovery.policyDigest,
            policySource: recovery.policySource
        )
    }
}
