public import GitHub_Standard
public import Institute_Model

extension Institute.Source {
    public enum Workspace {}
}

extension Institute.Source.Workspace {
    /// The `owner/name` a Git remote URL names: its last two path segments,
    /// without `.git`, whatever the host and the scheme (`https://`, `ssh://`,
    /// `git@host:owner/name`, or a local proxy's `/git/owner/name`).
    public static func repository(remote: Swift.String) -> GitHub_Standard::GitHub.Repository.Slug? {
        var path = Swift.Substring(remote)
        var hosted = false
        if let scheme = path.firstRange(of: "://") {
            path = path[scheme.upperBound...]
            hosted = true
        }
        while path.hasSuffix("/") { path = path.dropLast() }
        if path.hasSuffix(".git") { path = path.dropLast(4) }
        let segments = path.split(whereSeparator: { $0 == "/" || $0 == ":" })
        guard segments.count >= (hosted ? 3 : 2) else { return nil }
        return GitHub_Standard::GitHub.Repository.Slug(segments.suffix(2).joined(separator: "/"))
    }
}
