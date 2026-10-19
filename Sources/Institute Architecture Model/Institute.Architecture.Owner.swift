public import Institute_Model

extension Institute.Architecture {
    /// The exact semantic owner of one package root: the organization and
    /// repository name that own a concept.
    ///
    /// Ownership is an identity, never a display string; two owners are the
    /// same exactly when both components match.
    public struct Owner: Sendable, Equatable, Hashable {
        public let organization: Swift.String
        public let name: Swift.String

        public init(organization: Swift.String, name: Swift.String) {
            self.organization = organization
            self.name = name
        }

        /// Whether this owner can be represented by one canonical artifact
        /// coordinate.
        ///
        /// Coordinates have exactly two non-empty components separated by
        /// one slash. Components cannot contain an artifact field or line
        /// delimiter.
        public var isCanonical: Swift.Bool {
            !organization.isEmpty
                && !name.isEmpty
                && !organization.contains(where: { $0 == "/" || $0 == "\t" || $0.isNewline })
                && !name.contains(where: { $0 == "/" || $0 == "\t" || $0.isNewline })
        }

        /// Creates an owner from one canonical artifact coordinate.
        public init?(coordinate: Swift.String) {
            let components = coordinate.split(separator: "/", omittingEmptySubsequences: false)
            guard components.count == 2 else { return nil }
            let owner = Self(
                organization: Swift.String(components[0]),
                name: Swift.String(components[1])
            )
            guard owner.isCanonical else { return nil }
            self = owner
        }
    }
}

extension Institute.Architecture.Owner: Comparable {
    public static func < (
        lhs: Institute.Architecture.Owner,
        rhs: Institute.Architecture.Owner
    ) -> Swift.Bool {
        (lhs.organization, lhs.name) < (rhs.organization, rhs.name)
    }
}

extension Institute.Architecture.Owner: CustomStringConvertible {
    public var description: Swift.String {
        "\(organization)/\(name)"
    }
}
