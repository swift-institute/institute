public import GitHub_Standard
public import Institute_Model

extension Institute.Repository.Policy {
    public enum Prose {}
}

extension Institute.Repository.Policy.Prose {
    public static let extensions: Swift.Set<Swift.String> = ["md", "markdown", "mdx"]

    public static func findings(in tracked: [Swift.String], repository: GitHub_Standard::GitHub.Repository.Slug) -> [Swift.String] {
        guard !Admitted.repositories.contains(repository.description) else { return [] }
        let communityHealth = repository.description.split(separator: "/").last == ".github"
        return tracked.filter { path in
            isProse(path) && !isAdmitted(path, communityHealth: communityHealth)
        }
        .sorted()
    }

    // swift-linter:disable:next raw concept
    // REASON: a tracked entry as the git index lists it, only quoted back; git admits names with control characters, which File.Path refuses, and such a file must still be reported.
    public static func message(_ path: Swift.String) -> Swift.String {
        "`\(path)` is prose outside README.md. A repository's prose is its README.md, written for agents to read "
            + "first; fold this into it or delete it. Admitted besides: LICENSE.md, an organization's community-health "
            + "files in its .github repository, DocC catalogs, and test fixtures under a tests directory's fixtures."
    }

    static func isProse(_ path: Swift.String) -> Swift.Bool {
        guard let name = path.split(separator: "/").last, let dot = name.lastIndex(of: ".") else { return false }
        return extensions.contains(name[name.index(after: dot)...].lowercased())
    }

    static func isFixture(_ components: [Swift.Substring]) -> Swift.Bool {
        let directories = components.dropLast().map { $0.lowercased() }
        guard let tests = directories.firstIndex(of: "tests") else { return false }
        return directories[(tests + 1)...].contains("fixtures")
    }

    static func isAdmitted(_ path: Swift.String, communityHealth: Swift.Bool) -> Swift.Bool {
        let components = path.split(separator: "/", omittingEmptySubsequences: true)
        if components.dropLast().contains(where: { $0.hasSuffix(".docc") }) { return true }
        if isFixture(components) { return true }
        if Admitted.root.contains(path) { return true }
        guard communityHealth else { return false }
        let relative = components.first == ".github" ? components.dropFirst().joined(separator: "/") : path
        if Admitted.organization.contains(relative) { return true }
        let templates = relative.lowercased()
        return templates.hasPrefix("issue_template/") || templates.hasPrefix("pull_request_template")
    }
}
