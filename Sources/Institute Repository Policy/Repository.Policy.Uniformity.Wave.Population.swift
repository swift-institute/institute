extension Repository.Policy.Uniformity.Wave {
    public struct Population: Codable, Sendable, Equatable {
        public let organizations: [String]
        /// The organizations with at least one subject — the exact
        /// preflight/apply/closure matrix. Derived, never supplied: a
        /// zero-subject organization must not become a matrix row.
        public let subjectOrganizations: [String]
        /// The zero-subject organizations, each with its typed reason.
        /// Together with ``subjectOrganizations`` this partitions
        /// ``organizations`` exactly.
        public let organizationExclusions: [OrganizationExclusion]
        public let examined: Int
        public let repositoryCounts: [String: Int]
        public let repositories: [String]
        public let excluded: [String: Int]
        public let subjects: [Subject]
        public let commitment: Commitment

        public init(
            organizations: [String],
            examined: Int,
            repositoryCounts: [String: Int] = [:],
            repositories: [String]? = nil,
            excluded: [String: Int],
            subjects: [Subject],
            organizationExclusionReasons: [String: String] = [:]
        ) {
            let organizations = organizations.sorted()
            let repositories = (repositories ?? subjects.map(\.repository)).sorted()
            let subjects = subjects.sorted(by: { $0.repository < $1.repository })
            self.organizations = organizations
            let subjectOrganizations = Set(
                subjects.map { String($0.repository.prefix(while: { $0 != "/" })) }
            )
            self.subjectOrganizations = organizations.filter(subjectOrganizations.contains)
            self.organizationExclusions =
                organizations
                .filter { !subjectOrganizations.contains($0) }
                .map {
                    OrganizationExclusion(
                        organization: $0,
                        reason: organizationExclusionReasons[$0]
                            ?? OrganizationExclusion.noSubjects
                    )
                }
            self.examined = examined
            self.repositoryCounts = repositoryCounts
            self.repositories = repositories
            self.excluded = excluded
            self.subjects = subjects
            self.commitment = Self.commitment(repositories: repositories, subjects: subjects)
        }

        public func validate() throws(Error) {
            guard organizations == organizations.sorted(),
                repositories == repositories.sorted(),
                subjects.map(\.repository) == subjects.map(\.repository).sorted()
            else {
                throw .population("population commitment is not sorted")
            }
            guard Set(organizations).count == organizations.count else {
                throw .population("population contains a duplicated organization")
            }
            guard Set(repositories).count == repositories.count else {
                throw .population("population contains a duplicated repository")
            }
            guard Set(subjects.map(\.repository)).count == subjects.count else {
                throw .population("population contains a duplicated subject")
            }
            guard
                repositoryCounts.isEmpty
                    || Set(repositoryCounts.keys) == Set(organizations)
            else {
                throw .population("population organization counts do not cover the exact fleet")
            }
            guard examined == repositoryCounts.values.reduce(0, +) || repositoryCounts.isEmpty
            else {
                throw .population(
                    "population examined count \(examined) does not equal organization counts"
                )
            }
            guard repositories.count == examined || repositoryCounts.isEmpty else {
                throw .population(
                    "population repository set has \(repositories.count) entries; expected \(examined)"
                )
            }
            guard subjects.allSatisfy({ repositories.contains($0.repository) }) else {
                throw .population("population contains a subject outside its repository set")
            }
            guard subjects.count + excluded.values.reduce(0, +) == examined else {
                throw .population("population eligibility accounting is incomplete")
            }
            let expected = Self.commitment(repositories: repositories, subjects: subjects)
            guard commitment == expected else {
                throw .population("population commitment digest does not match its subjects")
            }
            let derived = Set(subjects.map { String($0.repository.prefix(while: { $0 != "/" })) })
            guard subjectOrganizations == organizations.filter(derived.contains) else {
                throw .population(
                    "population matrix organizations do not equal the subject-bearing set"
                )
            }
            guard
                organizationExclusions.map(\.organization)
                    == organizations.filter({ !derived.contains($0) })
            else {
                throw .population(
                    "population organization exclusions do not cover the zero-subject set"
                )
            }
            guard organizationExclusions.allSatisfy({ !$0.reason.isEmpty }) else {
                throw .population("population organization exclusion carries an empty reason")
            }
        }

        private static func commitment(
            repositories: [String],
            subjects: [Subject]
        ) -> Commitment {
            let names = subjects.map(\.repository)
            let state = subjects.flatMap {
                [
                    $0.repository,
                    String($0.repositoryID),
                    $0.head,
                    $0.manifest.kind,
                    $0.manifest.blob,
                ] + $0.shape.digestComponents
            }
            return .init(
                repositories: repositories.count,
                subjects: subjects.count,
                repositoryDigest: Repository.Policy.Caller.Wave.digest(repositories),
                subjectDigest: Repository.Policy.Caller.Wave.digest(names),
                stateDigest: Repository.Policy.Caller.Wave.digest(state)
            )
        }
    }
}
