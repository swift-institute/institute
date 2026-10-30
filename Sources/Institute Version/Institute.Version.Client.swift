public import Institute_Model

extension Institute.Version {
    /// The tagging's network boundary: what the sweep reads of an
    /// organization and its repositories, and the one write it makes.
    /// Tests bind these closures to an in-memory organization.
    ///
    /// There is deliberately no operation that moves or deletes a ref.
    public struct Client: Swift.Sendable {
        public typealias Subjects =
            @Sendable (Institute.Organization) throws(Institute.Version.Error) -> [Subject]
        /// The commit `main` points at, or nil when there is no `main`.
        public typealias Head =
            @Sendable (Institute.Repository.Coordinate) throws(Institute.Version.Error) -> Swift.String?
        /// Every tag whose name starts with the prefix.
        public typealias Tags =
            @Sendable (Institute.Repository.Coordinate, _ prefix: Swift.String) throws(Institute.Version.Error)
            -> [Tag]
        public typealias Judge =
            @Sendable (Institute.Repository.Coordinate, _ commit: Swift.String) throws(Institute.Version.Error)
            -> Gate
        public typealias Compare =
            @Sendable (Institute.Repository.Coordinate, _ base: Swift.String, _ head: Swift.String)
            throws(Institute.Version.Error) -> Relation
        /// Creates the tag, or reports the commit an existing tag of that
        /// name already names. Never replaces a ref.
        public typealias Create =
            @Sendable (Institute.Repository.Coordinate, Tag) throws(Institute.Version.Error) -> Creation

        public let subjects: Subjects
        public let head: Head
        public let tags: Tags
        public let gate: Judge
        public let relation: Compare
        public let create: Create

        public init(
            subjects: @escaping Subjects,
            head: @escaping Head,
            tags: @escaping Tags,
            gate: @escaping Judge,
            relation: @escaping Compare,
            create: @escaping Create
        ) {
            self.subjects = subjects
            self.head = head
            self.tags = tags
            self.gate = gate
            self.relation = relation
            self.create = create
        }
    }
}

extension Institute.Version.Client {
    /// The answer to a tag creation.
    public enum Creation: Swift.Hashable, Swift.Sendable {
        case created
        /// A tag of that name already exists and names this commit.
        case exists(commit: Swift.String)
    }
}
