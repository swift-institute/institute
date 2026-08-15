public import GitHub
public import Institute_Model
public import Tagged_Primitives

extension Institute.Inventory {
    public struct Merge: Sendable {
        public init() {}
    }
}

extension Institute.Inventory.Merge {
    public func callAsFunction(
        _ discovery: Institute.Inventory.Discovery,
        into existing: Institute.Configuration
    ) throws(Error) -> Institute.Configuration {
        var annotations = [Institute.Repository.Key: Institute.Repository]()
        var oldNames = [GitHub.Repository.Name: Institute.Repository.Key]()
        for repository in existing.repositories {
            guard let key = Institute.Repository.Key(repository: repository) else {
                throw .annotation(repository)
            }
            guard annotations[key] == nil else { throw .duplicate(key) }
            if let first = oldNames[key.name], first != key {
                throw .collision(key.name, first, key)
            }
            annotations[key] = repository
            oldNames[key.name] = key
        }

        var keys = Set<Institute.Repository.Key>()
        var newNames = [GitHub.Repository.Name: Institute.Repository.Key]()
        var repositories = [(key: Institute.Repository.Key, value: Institute.Repository)]()
        for candidate in discovery.repositories {
            guard keys.insert(candidate.key).inserted else {
                throw .duplicate(candidate.key)
            }
            if let first = newNames[candidate.key.name], first != candidate.key {
                throw .collision(candidate.key.name, first, candidate.key)
            }
            newNames[candidate.key.name] = candidate.key

            if let previous = oldNames[candidate.key.name], previous != candidate.key {
                guard let annotation = annotations[previous] else {
                    preconditionFailure("An indexed annotation is missing")
                }
                throw .transfer(
                    candidate.key.name,
                    previous,
                    candidate.key,
                    annotation: annotation.layer,
                    default: candidate.layer
                )
            }

            let layer = annotations[candidate.key]?.layer ?? candidate.layer
            repositories.append(
                (
                    candidate.key,
                    .init(
                        name: candidate.key.name.underlying,
                        url: candidate.key.url,
                        organization: candidate.key.owner.underlying,
                        layer: layer
                    )
                )
            )
        }

        repositories.sort { lhs, rhs in
            if lhs.value.layer.order != rhs.value.layer.order {
                return lhs.value.layer.order < rhs.value.layer.order
            }
            return Institute.Repository.Key.precedes(lhs.key, rhs.key)
        }

        return .init(
            version: existing.version,
            scope: existing.scope,
            swift: existing.swift,
            xcode: existing.xcode,
            repositories: repositories.map(\.value)
        )
    }
}
