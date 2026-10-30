public import Institute_Model

extension Institute.Source.Policy {
    /// The engine rules reported as warnings in `Tests/` and as errors
    /// everywhere else: force-try, force-unwrap and early-exit style.
    ///
    /// Tests fail by trapping, so `try!`, `!` and nested guards are how a
    /// test states "this setup cannot fail". In `Sources/` the same
    /// constructs are crashes shipped to consumers, so they stay errors.
    /// Neither engine can scope a rule by path, so the severity is decided
    /// after measurement, on the finding's own identifier and location.
    internal static let testsOnlyWarningIdentifiers: Swift.Set<Swift.String> = [
        "NeverForceUnwrap",
        "NeverUseForceTry",
        "UseEarlyExits",
        "force_try",
    ]

    /// Whether a finding with `identifier` at `path` is reported as a warning.
    ///
    /// `path` is as the engine reported it, absolute or relative to `root`.
    public func reportsAsWarning(
        identifier: Swift.String,
        path: Swift.String,
        root: Swift.String
    ) -> Swift.Bool {
        guard Self.testsOnlyWarningIdentifiers.contains(identifier) else { return false }
        let prefix = root.hasSuffix("/") ? root : root + "/"
        let relative = path.hasPrefix(prefix) ? Swift.String(path.dropFirst(prefix.count)) : path
        return relative.hasPrefix("Tests/")
    }
}
