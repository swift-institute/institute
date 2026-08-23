public import Institute_Model

extension Institute.Repository.Policy.Caller.Wave {
    public static func enumerate<C: Client>(
        client: C,
        fleet: RepositoryPolicy.Fleet
    ) async throws(Error) -> Population {
        let organizations = fleet.activeOrganizationNames.sorted()
        guard !organizations.isEmpty else {
            throw .population("fleet policy has no active organizations")
        }
        var examined = 0
        var excluded: [String: Int] = [:]
        var seen: Set<String> = []
        var candidates: [RepositoryPolicy.Repository] = []
        var repositoryCounts: [String: Int] = [:]
        var repositoryNames: [String] = []
        var notPublicCounts: [String: Int] = [:]
        for organization in organizations {
            let listing = try await calling {
                try await client.waveRepositories(organization: organization)
            }
            let repositories = listing.repositories
            guard !repositories.isEmpty else {
                throw .population("\(organization): public repository enumeration was empty")
            }
            guard repositories.count == listing.expected else {
                throw .population(
                    "\(organization): repository listing contained \(repositories.count); "
                        + "expected \(listing.expected)"
                )
            }
            repositoryCounts[organization] = listing.expected
            examined += repositories.count
            for repository in repositories.sorted(by: { $0.fullName < $1.fullName }) {
                guard repository.owner == organization else {
                    throw .population(
                        "\(organization): enumeration returned foreign repository \(repository.fullName)"
                    )
                }
                guard seen.insert(repository.fullName.lowercased()).inserted else {
                    throw .population("duplicate repository \(repository.fullName)")
                }
                repositoryNames.append(repository.fullName)
                if let reason = RepositoryPolicy.staticExclusion(of: repository) {
                    excluded[reason.rawValue, default: 0] += 1
                    if reason == .notPublic {
                        notPublicCounts[organization, default: 0] += 1
                    }
                    continue
                }
                candidates.append(repository)
            }
        }
        let measurements = try await boundedMeasurements(client: client, candidates: candidates)
        var subjects: [Subject] = []
        var missingCallers: [String] = []
        for measurement in measurements {
            switch measurement {
            case .excluded(let reason): excluded[reason, default: 0] += 1

            case .missingCaller(let repository): missingCallers.append(repository)

            case .subject(let subject): subjects.append(subject)
            }
        }
        guard missingCallers.isEmpty else {
            throw .population(
                "eligible repositories missing .github/workflows/ci.yml: "
                    + missingCallers.sorted().joined(separator: ", ")
            )
        }
        guard !subjects.isEmpty else {
            throw .population("active fleet enumeration produced zero eligible callers")
        }
        // A zero-subject organization is a typed census fact, never a
        // preflight matrix row (wave run 31817391995, swift-riscv). The
        // reason distinguishes an organization the public wave cannot
        // even see from one whose public repositories all fell to
        // eligibility.
        var exclusionReasons: [String: String] = [:]
        for organization in organizations
        where !subjects.contains(where: { $0.repository.hasPrefix(organization + "/") }) {
            exclusionReasons[organization] =
                notPublicCounts[organization] == repositoryCounts[organization]
                ? Population.OrganizationExclusion.privateOnly
                : Population.OrganizationExclusion.noSubjects
        }
        let population = Population(
            organizations: organizations,
            examined: examined,
            repositoryCounts: repositoryCounts,
            repositories: repositoryNames,
            excluded: excluded,
            subjects: subjects.sorted(by: { $0.repository < $1.repository }),
            organizationExclusionReasons: exclusionReasons
        )
        try population.validate()
        return population
    }

    private static func boundedMeasurements<C: Client>(
        client: C,
        candidates: [RepositoryPolicy.Repository]
    ) async throws(Error) -> [Measurement] {
        do {
            return try await withThrowingTaskGroup(of: Measurement.self) { group in
                var iterator = candidates.makeIterator()
                for _ in 0..<min(16, candidates.count) {
                    guard let repository = iterator.next() else { break }
                    group.addTask { try await measure(client: client, repository: repository) }
                }
                var result: [Measurement] = []
                while let measurement = try await group.next() {
                    result.append(measurement)
                    if let repository = iterator.next() {
                        group.addTask { try await measure(client: client, repository: repository) }
                    }
                }
                return result
            }
        } catch let error as Institute_Model.Institute.Repository.Policy.Caller.Wave.Error {
            throw error
        } catch {
            throw .verification("fleet measurement failed unexpectedly: \(error)")
        }
    }

    private static func measure<C: Client>(
        client: C,
        repository: RepositoryPolicy.Repository
    ) async throws(Error) -> Measurement {
        let live = try await calling {
            try await client.waveRepository(repository.fullName)
        }
        guard live.id == repository.id else {
            throw .population("\(repository.fullName): repository identity moved during census")
        }
        guard live.visibility == "public", !live.archived, !live.disabled else {
            throw .population("\(repository.fullName): eligibility moved during census")
        }
        guard live.defaultBranch == "main" else {
            throw .population(
                "\(repository.fullName): eligible package default branch is not main"
            )
        }
        let head = try await calling { try await client.head(repository.fullName) }
        let manifest = try await calling {
            try await client.rootManifest(repository.fullName, head: head)
        }
        let manifestFact: Institute_Model.Institute.Repository.Policy.Eligibility.Subject.Manifest
        switch manifest?.kind {
        case "file": manifestFact = .present

        case nil: manifestFact = .absent

        default:
            throw .population(
                "\(repository.fullName): root Package.swift is not a regular file"
            )
        }
        switch Institute_Model.Institute.Repository.Policy.Eligibility.verdict(
            .init(repository: repository.fullName, rootManifest: manifestFact)
        ) {
        case .noManifest:
            return .excluded("missing-root-manifest")

        case .bespoke:
            return .excluded("bespoke-ci")

        case .eligible:
            break
        }
        let verifiedRepository = try await calling {
            try await client.waveRepository(repository.fullName)
        }
        let caller = try await calling {
            try await client.callerSourceIfPresent(repository.fullName, head: head)
        }
        guard let caller else { return .missingCaller(repository.fullName) }
        let verifiedHead = try await calling { try await client.head(repository.fullName) }
        guard live == verifiedRepository, head == verifiedHead else {
            throw .population("\(repository.fullName): census facts moved during measurement")
        }
        guard let manifest else {
            throw .population("\(repository.fullName): eligible manifest was absent")
        }
        return .subject(
            .init(
                repository: repository.fullName,
                repositoryID: repository.id,
                head: head,
                manifest: manifest,
                caller: caller
            )
        )
    }
}
