internal import Institute_Model
internal import Package_Manager

extension Institute.Inventory.Assembly {
    /// The target graph across packages, for visibility.
    struct Graph {
        let members: [Institute.Inventory.Member]
        let targets: [Institute.Inventory.Target]
        let targetIndex: [[Swift.String: Swift.Int]]
        let dependencyPackages: [[Swift.String: Swift.Int]]
    }
}

extension Institute.Inventory.Assembly.Graph {
    func sameTarget(_ name: Swift.String, package: Swift.Int) -> Swift.Int? {
        targetIndex[package][name]
    }

    /// The targets a product of `package` lists.
    func product(_ name: Swift.String, in package: Swift.Int) -> [Swift.Int] {
        guard let product = members[package].evaluation.products.first(where: { $0.name.underlying == name })
        else { return [] }
        return product.targets.compactMap { targetIndex[package][$0.underlying] }
    }

    func direct(_ target: Swift.Int) -> [Swift.Int] {
        let package = targets[target].package
        var result: [Swift.Int] = []
        for dependency in targets[target].manifest.dependencies {
            switch dependency {
            case .target(let name):
                if let found = sameTarget(name.underlying, package: package) { result.append(found) }
            case .byName(let name):
                if let found = sameTarget(name, package: package) {
                    result.append(found)
                } else {
                    for other in dependencyPackages[package].values { result += product(name, in: other) }
                }
            case .product(let name, let from):
                let token = from.underlying.lowercased()
                let other =
                    dependencyPackages[package][token]
                    ?? dependencyPackages[package].values.first {
                        members[$0].evaluation.name.underlying.lowercased() == token
                    }
                if let other { result += product(name.underlying, in: other) }
            }
        }
        return result
    }

    /// The target itself and every target it reaches through target
    /// and product dependencies, conditions ignored.
    func visible(from target: Swift.Int) -> Swift.Set<Swift.Int> {
        var seen: Swift.Set<Swift.Int> = [target]
        var stack = [target]
        while let next = stack.popLast() {
            for dependency in direct(next) where seen.insert(dependency).inserted {
                stack.append(dependency)
            }
        }
        return seen
    }
}
