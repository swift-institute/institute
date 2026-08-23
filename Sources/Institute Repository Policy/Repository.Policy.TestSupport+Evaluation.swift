import Package_Manager

extension RepositoryPolicy.TestSupport {
    public static func findings(
        in evaluation: Package.Manifest.Evaluation
    ) -> [Finding] {
        let supportedTargets = Swift.Set(
            evaluation.products.flatMap(\.targets).map(\.underlying)
        )

        return evaluation.targets.flatMap { target -> [Finding] in
            let targetName = target.name.underlying
            guard isTestSupport(targetName) else { return [] }

            return target.dependencies.compactMap { dependency in
                let name: Swift.String
                switch dependency {
                case .byName(let value): name = value
                case .product(let value, _): name = value.underlying
                case .target(let value): name = value.underlying
                }
                guard !isTestSupport(name), !supportedTargets.contains(name) else {
                    return nil
                }
                return Finding(target: targetName, dependency: name)
            }
        }.sorted {
            ($0.target, $0.dependency) < ($1.target, $1.dependency)
        }
    }

    private static func isTestSupport(_ name: Swift.String) -> Swift.Bool {
        name.hasSuffix(" Test Support")
    }
}
