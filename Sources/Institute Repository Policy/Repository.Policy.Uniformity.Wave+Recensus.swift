
extension Repository.Policy.Uniformity.Wave {
    public static func recensus(
        original: Population,
        current: Population,
        evidence: Recensus.Evidence
    ) throws(Error) -> Recensus {
        try original.validate()
        try current.validate()
        let canonicalDigest = Repository.Policy.Caller.Wave.digest(evidence.payload)
        let originalSubjects = Dictionary(
            uniqueKeysWithValues: original.subjects.map { ($0.repository, $0) }
        )
        let currentSubjects = Dictionary(
            uniqueKeysWithValues: current.subjects.map { ($0.repository, $0) }
        )
        let receiptMap = unique(evidence.receipts, key: \Receipt.repository)
        let closureMap = unique(evidence.closures, key: \Closure.repository)
        let eventRepositories = Set(evidence.events.map(\.repository))
        let expectedRepositories = Set(originalSubjects.keys)
        let stablePopulation =
            original.organizations == current.organizations
            && original.examined == current.examined
            && original.repositoryCounts == current.repositoryCounts
            && original.repositories == current.repositories
            && original.commitment.repositories == current.commitment.repositories
            && original.commitment.subjects == current.commitment.subjects
            && original.commitment.repositoryDigest == current.commitment.repositoryDigest
            && original.commitment.subjectDigest == current.commitment.subjectDigest
            && Set(currentSubjects.keys) == expectedRepositories
        let exactEvidence =
            receiptMap?.count == expectedRepositories.count
            && closureMap?.count == expectedRepositories.count
            && eventRepositories == expectedRepositories
            && Set(receiptMap?.keys.map { $0 } ?? []) == expectedRepositories
            && Set(closureMap?.keys.map { $0 } ?? []) == expectedRepositories
        let observations = current.subjects.map { subject in
            let prior = originalSubjects[subject.repository]
            let receipt = receiptMap?[subject.repository]
            let closure = closureMap?[subject.repository]
            let terminalEvents = evidence.events.filter {
                $0.repository == subject.repository
                    && ($0.phase == "applied" || $0.phase == "already-terminal")
            }
            let eventAccepted =
                terminalEvents.count == 1
                && terminalEvents[0].bypassClosed == true
                && terminalEvents[0].populationDigest == original.commitment.stateDigest
                && terminalEvents[0].policyDigest == evidence.policyDigest
                && terminalEvents[0].policySource == evidence.policySource
            let subjectStable =
                prior?.repositoryID == subject.repositoryID
                && prior?.manifest == subject.manifest
            let receiptAccepted =
                receipt?.oldHead == prior?.head
                && receipt?.oldGitignore == prior?.shape.gitignore?.blob
                && receipt?.newHead == subject.head
                && receipt.map { $0.newGitignore == subject.shape.gitignore?.blob } == true
                && receipt?.bypassClosed == true
                && receipt?.population == original.commitment
                && receipt?.policyDigest == evidence.policyDigest
                && receipt?.policySource == evidence.policySource
            let closureAccepted =
                closure?.head == subject.head
                && closure?.gitignore == subject.shape.gitignore?.blob
                && closure?.gitignoreDigest == canonicalDigest
                && closure?.accepted == true
                && closure?.population == original.commitment
                && closure?.policyDigest == evidence.policyDigest
                && closure?.policySource == evidence.policySource
                && closure?.ruleset == receipt?.ruleset
            return Observation(
                repository: subject.repository,
                head: subject.head,
                gitignore: subject.shape.gitignore?.blob,
                digest: subject.shape.gitignore.map {
                    Repository.Policy.Caller.Wave.digest($0.bytes)
                },
                matches: subject.shape.terminal(payload: evidence.payload)
                    && subjectStable
                    && receiptAccepted
                    && eventAccepted
                    && closureAccepted
            )
        }
        return Recensus(
            organizations: current.organizations,
            examined: current.examined,
            excluded: current.excluded,
            originalPopulation: original.commitment,
            currentPopulation: current.commitment,
            canonicalDigest: canonicalDigest,
            policyDigest: evidence.policyDigest,
            policySource: evidence.policySource,
            receipts: evidence.receipts.count,
            closures: evidence.closures.count,
            observations: observations,
            accepted: stablePopulation && exactEvidence && !observations.isEmpty
                && observations.allSatisfy(\.matches)
        )
    }

    private static func unique<Value>(
        _ values: [Value],
        key: KeyPath<Value, String>
    ) -> [String: Value]? {
        var result: [String: Value] = [:]
        for value in values {
            guard result.updateValue(value, forKey: value[keyPath: key]) == nil else {
                return nil
            }
        }
        return result
    }
}
