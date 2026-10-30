extension Institute.Repository {
    public struct Coordinate: Swift.Hashable, Swift.Sendable {
        public let organization: Institute.Organization
        public let name: Swift.String

        public init(organization: Institute.Organization, name: Swift.String) {
            self.organization = organization
            self.name = name
        }

        public init?(_ repository: Swift.String) {
            let components = repository.split(separator: "/", omittingEmptySubsequences: false)
            guard components.count == 2, !components[1].isEmpty,
                let organization = Institute.Organization(rawValue: Swift.String(components[0]))
            else { return nil }
            self.init(organization: organization, name: Swift.String(components[1]))
        }
    }
}

extension Institute.Repository.Coordinate {
    public static let variable: Swift.String = "INSTITUTE_REPOSITORY"

    public var description: Swift.String { "\(organization.rawValue)/\(name)" }
}
