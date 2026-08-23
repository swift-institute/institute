import Package_Manager

extension RepositoryPolicy.BranchPin {
    public static func findings(
        in dependencies: [Package.Manifest.Dependency.SourceControl],
        organizations: Swift.Set<Swift.String>
    ) -> [Finding] {
        dependencies.compactMap { dependency in
            guard let branch = dependency.branch, branch != "main",
                let organization = organization(of: dependency.url),
                organizations.contains(organization)
            else { return nil }
            return .init(
                document: dependency.document,
                url: dependency.url,
                branch: branch
            )
        }.sorted {
            ($0.document, $0.url, $0.branch) < ($1.document, $1.url, $1.branch)
        }
    }

    private static func organization(of url: Swift.String) -> Swift.String? {
        var value = url[...]
        if let colon = value.firstIndex(of: ":") {
            value = value[value.index(after: colon)...]
        }
        let components = value.split(separator: "/")
        guard components.count >= 2 else { return nil }
        return Swift.String(components[components.count - 2]).lowercased()
    }
}
