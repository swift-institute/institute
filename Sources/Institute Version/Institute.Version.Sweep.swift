public import Institute_Model

extension Institute.Version {
    /// One pass over a set of repositories that tags each `main` head
    /// that has earned the line's next version.
    ///
    /// A sweep is safe to repeat and to race: it reads before it writes,
    /// a head already on the line is left alone, the one write is a ref
    /// creation that GitHub refuses when the name exists, and a refused
    /// creation is read back rather than retried. Versions are dense per
    /// repository: a commit that is superseded on `main` before it is
    /// tagged is simply never versioned.
    public struct Sweep: Swift.Sendable {
        public let line: Line
        public let mode: Mode
        /// When true, nothing is written; `planned` reports the tag a real
        /// sweep would create.
        public let dryRun: Swift.Bool
        public let client: Client

        public init(line: Line = .development, mode: Mode, dryRun: Swift.Bool, client: Client) {
            self.line = line
            self.mode = mode
            self.dryRun = dryRun
            self.client = client
        }
    }
}

extension Institute.Version.Sweep {
    public enum Mode: Swift.String, Swift.Hashable, Swift.Sendable {
        /// Tag every head that passed CI and is not yet on the line.
        case continuous
        /// Tag only repositories with no tag on the line yet, once.
        case backfill
    }

    /// The reports for every repository of `organizations`, by name, or
    /// only for `repositories` when any are named.
    public func run(
        _ organizations: [Institute.Organization],
        repositories: Swift.Set<Institute.Repository.Coordinate> = []
    ) -> [Institute.Version.Report] {
        var reports: [Institute.Version.Report] = []
        for organization in organizations {
            let subjects: [Institute.Version.Subject]
            do throws(Institute.Version.Error) {
                subjects = try client.subjects(organization)
            } catch {
                reports.append(
                    .init(
                        repository: .init(organization: organization, name: "*"),
                        head: nil,
                        outcome: .failed(error)
                    )
                )
                continue
            }
            let selected = subjects.filter { repositories.isEmpty || repositories.contains($0.repository) }
            for subject in selected.sorted(by: { $0.repository.name < $1.repository.name }) {
                reports.append(report(subject))
            }
        }
        return reports
    }

    /// The report for one repository. Every failure is caught here, so one
    /// repository never stops the sweep of the others.
    public func report(_ subject: Institute.Version.Subject) -> Institute.Version.Report {
        let repository = subject.repository
        if subject.archived { return .init(repository: repository, head: nil, outcome: .skipped(.archived)) }
        if subject.private { return .init(repository: repository, head: nil, outcome: .skipped(.private)) }
        let head: Swift.String?
        do throws(Institute.Version.Error) {
            head = try client.head(repository)
        } catch {
            return .init(repository: repository, head: nil, outcome: .failed(error))
        }
        guard let head else { return .init(repository: repository, head: nil, outcome: .skipped(.unbranched)) }
        do throws(Institute.Version.Error) {
            return .init(repository: repository, head: head, outcome: try outcome(repository, head: head))
        } catch {
            return .init(repository: repository, head: head, outcome: .failed(error))
        }
    }

    private func outcome(
        _ repository: Institute.Repository.Coordinate,
        head: Swift.String
    ) throws(Institute.Version.Error) -> Institute.Version.Outcome {
        let tags = try client.tags(repository, line.stem).compactMap { tag -> (Swift.Int, Institute.Version.Tag)? in
            line.ordinal(of: tag.name).map { ($0, tag) }
        }
        if let current = tags.filter({ $0.1.commit == head }).max(by: { $0.0 < $1.0 }) {
            return .current(current.1)
        }
        let latest = tags.max(by: { $0.0 < $1.0 })
        if mode == .backfill, let latest { return .versioned(latest.1) }

        switch try client.gate(repository, head) {
        case .passed: break
        case .failed(let conclusion): return .held(conclusion)
        case let gate: return .waiting(gate)
        }

        if let latest {
            let relation = try client.relation(repository, latest.1.commit, head)
            guard relation == .ahead else { return .refused(latest: latest.1, relation: relation) }
        }
        let tag = Institute.Version.Tag(
            name: line.tag(line.next(after: tags.map(\.0))),
            commit: head
        )
        if dryRun { return .planned(tag) }
        switch try client.create(repository, tag) {
        case .created:
            return .tagged(tag)
        case .exists(let commit) where commit == head:
            return .current(tag)
        case .exists(let commit):
            return .contended(tag, existing: commit)
        }
    }
}
