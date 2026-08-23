public import Institute_Model
public import Byte_Primitives

extension Institute.Repository.Policy.Uniformity.Wave {
    public static func close<C: Client>(
        client: C,
        recovery: Recovery,
        payload: [Byte]
    ) async throws(Error) -> Closure {
        guard Institute.Repository.Policy.Caller.Wave.digest(payload) == recovery.payloadDigest
        else {
            throw .verification("\(recovery.repository): closure payload digest moved")
        }
        let repository = try await calling {
            try await client.waveRepository(recovery.repository)
        }
        let head = try await calling { try await client.head(recovery.repository) }
        let manifest = try await calling {
            try await client.rootManifest(recovery.repository, head: head)
        }
        let shape = try await shape(client: client, repository: recovery.repository, head: head)
        let references = try await Institute.Repository.Policy.Caller.Wave.protectedMainReferences(
            client: client,
            recovery.repository
        )
        let rulesetID = references.first?.id
        if let rulesetID {
            try await Institute.Repository.Policy.Caller.Wave.closeBypass(
                client: client,
                repository: recovery.repository,
                rulesetID: rulesetID,
                integrationID: recovery.integrationID
            )
        }
        let finalRuleset: [Byte]?
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
        let shapeTerminal =
            shape.terminal(payload: payload)
            && shape.gitignore.map { Institute.Repository.Policy.Caller.Wave.digest($0.bytes) }
                == recovery.payloadDigest
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
            gitignore: shape.gitignore?.blob,
            gitignoreDigest: shape.gitignore.map {
                Institute.Repository.Policy.Caller.Wave.digest($0.bytes)
            },
            shapeTerminal: shapeTerminal,
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
