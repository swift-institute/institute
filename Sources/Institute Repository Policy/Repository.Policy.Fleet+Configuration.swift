extension RepositoryPolicy.Fleet {
    public func configuration(
        for repository: Swift.String
    ) throws(Error) -> Configuration {
        let owner = try self.owner(of: repository)
        guard
            let organization = organizations.first(where: {
                $0.name == owner && $0.status == "active"
            })
        else {
            throw .inactiveOrganization(owner)
        }
        let lintBundle: Swift.String
        switch organization.layer {
        case "L1": lintBundle = "primitives"
        case "L2": lintBundle = "standards"
        case "L3", "control": lintBundle = "institute"
        default: throw .invalidLayer(organization.layer)
        }
        let authored = repositories?.first(where: { $0.name == repository })
        return Configuration(
            lintBundle: lintBundle,
            platforms: authored?.platforms ?? "",
            embeddedTarget: authored?.embeddedTarget ?? ""
        )
    }

    public func validate() throws(Error) {
        var organizationNames: Swift.Set<Swift.String> = []
        for organization in organizations {
            guard organizationNames.insert(organization.name).inserted else {
                throw .duplicateOrganization(organization.name)
            }
            switch organization.layer {
            case "L1", "L2", "L3", "control": break
            default: throw .invalidLayer(organization.layer)
            }
            switch organization.status {
            case "active", "inactive": break
            default: throw .invalidStatus(organization.status)
            }
        }

        var repositoryNames: Swift.Set<Swift.String> = []
        for repository in repositories ?? [] {
            guard repositoryNames.insert(repository.name).inserted else {
                throw .duplicateRepository(repository.name)
            }
            let owner = try self.owner(of: repository.name)
            guard activeOrganizationNames.contains(owner) else {
                throw .inactiveOrganization(owner)
            }
        }
    }

    private func owner(of repository: Swift.String) throws(Error) -> Swift.String {
        let components = repository.split(separator: "/", omittingEmptySubsequences: false)
        guard components.count == 2, components.allSatisfy({ !$0.isEmpty }) else {
            throw .malformedRepository(repository)
        }
        return Swift.String(components[0])
    }
}
