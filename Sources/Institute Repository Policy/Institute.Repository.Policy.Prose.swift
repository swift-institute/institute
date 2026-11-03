public import Institute_Model

extension Institute.Repository.Policy {
  public enum Prose {}
}

extension Institute.Repository.Policy.Prose {
  public enum Admitted {}
}

extension Institute.Repository.Policy.Prose.Admitted {
  public static let root: Swift.Set<Swift.String> = ["README.md", "LICENSE.md"]

  public static let organization: Swift.Set<Swift.String> = [
    "SECURITY.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "SUPPORT.md", "GOVERNANCE.md",
    "profile/README.md",
  ]
}

extension Institute.Repository.Policy.Prose {
  public static let extensions: Swift.Set<Swift.String> = ["md", "markdown", "mdx"]

  public static func findings(in tracked: [Swift.String], repository: Swift.String) -> [Swift
    .String]
  {
    let communityHealth = repository.split(separator: "/").last == ".github"
    return tracked.filter { path in
      isProse(path) && !isAdmitted(path, communityHealth: communityHealth)
    }
    .sorted()
  }

  public static func message(_ path: Swift.String) -> Swift.String {
    "`\(path)` is prose outside README.md. A repository's prose is its README.md, written for agents to read "
      + "first; fold this into it or delete it. Admitted besides: LICENSE.md, an organization's community-health "
      + "files in its .github repository, and DocC catalogs."
  }

  static func isProse(_ path: Swift.String) -> Swift.Bool {
    guard let name = path.split(separator: "/").last, let dot = name.lastIndex(of: ".") else {
      return false
    }
    return extensions.contains(name[name.index(after: dot)...].lowercased())
  }

  static func isAdmitted(_ path: Swift.String, communityHealth: Swift.Bool) -> Swift.Bool {
    let components = path.split(separator: "/", omittingEmptySubsequences: true)
    if components.dropLast().contains(where: { $0.hasSuffix(".docc") }) { return true }
    if Admitted.root.contains(path) { return true }
    guard communityHealth else { return false }
    let relative =
      components.first == ".github" ? components.dropFirst().joined(separator: "/") : path
    if Admitted.organization.contains(relative) { return true }
    let templates = relative.lowercased()
    return templates.hasPrefix("issue_template/") || templates.hasPrefix("pull_request_template")
  }
}
