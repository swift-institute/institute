extension Repository.Policy.Caller.Wave.Population {
    /// A fleet organization the census examined and excluded from the
    /// preflight matrix because it yielded no subjects, with the reason
    /// recorded as a typed fact rather than expressed as a failing
    /// matrix row (wave run 31817391995, Preflight · swift-riscv).
    ///
    /// - `private-only`: every repository the organization listed was
    ///   excluded as not public, so there is nothing a public wave may
    ///   even see.
    /// - `no-subjects`: the organization has public repositories, but
    ///   none survived eligibility (archived, forks, bespoke CI,
    ///   missing manifest, …).
    public struct OrganizationExclusion: Codable, Sendable, Equatable {
        public static let privateOnly = "private-only"
        public static let noSubjects = "no-subjects"

        public let organization: String
        public let reason: String

        public init(organization: String, reason: String) {
            self.organization = organization
            self.reason = reason
        }
    }
}
