public import Institute_Model

extension Institute.Repository.Policy.Prose {
    public enum Admitted {}
}

extension Institute.Repository.Policy.Prose.Admitted {
    public static let root: Swift.Set<Swift.String> = ["README.md", "LICENSE.md"]

    public static let repositories: Swift.Set<Swift.String> = ["swift-institute/Issues"]

    public static let organization: Swift.Set<Swift.String> = [
        "SECURITY.md", "CONTRIBUTING.md", "CODE_OF_CONDUCT.md", "SUPPORT.md", "GOVERNANCE.md",
        "profile/README.md",
    ]
}
