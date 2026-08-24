public import Institute_Inventory
public import Institute_Model

extension Institute.Workspace.Materialization {
    static func validate(
        specification: Institute.Workspace.Specification,
        catalog: Institute.Xcode.Catalog,
        configuration: Institute.Configuration
    ) throws(Institute.Error) {
        guard specification.dependency == .localInstituteClosure else { return }

        var inventory = [Swift.String: Institute.Repository.Key]()
        for repository in configuration.repositories {
            guard let key = Institute.Repository.Key(repository: repository) else {
                throw .configuration(
                    "inventory repository has noncanonical identity: \(repository.url)"
                )
            }
            guard inventory.updateValue(key, forKey: repository.url) == nil else {
                throw .configuration("inventory repository URL is duplicated: \(repository.url)")
            }
        }

        let selected = Set(specification.members.map { member in
            switch member.role {
            case .subject(let repository): repository
            case .control(let control): control.repository
            }
        })
        var missing = Set<Institute.Repository.Key>()
        for entry in catalog.entries {
            for dependency in entry.dependencies {
                guard let repository = inventory[dependency], !selected.contains(repository) else {
                    continue
                }
                missing.insert(repository)
            }
        }
        guard missing.isEmpty else {
            let identities = missing.map(\.identity).sorted().joined(separator: ", ")
            throw .configuration(
                "workspace local Institute dependency closure is incomplete; missing: [\(identities)]"
            )
        }
    }
}
