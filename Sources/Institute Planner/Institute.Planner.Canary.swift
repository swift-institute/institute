public import Institute_Model

extension Institute.Planner {
    /// The canary: the current and a candidate planner each measure the
    /// same canary repositories at the same revision with
    /// `ci -- source --exit-policy strict`, and the candidate is adoptable
    /// only when it reports nothing the current planner did not.
    public enum Canary {}
}

extension Institute.Planner.Canary {
    /// One repository per layer, chosen for having no commits since the
    /// current pin, so a difference between the two planners is the
    /// planner's and not the repository's.
    public static let repositories = [
        "swift-atoms/swift-addition",
        "swift-molecules/swift-array",
        "swift-ietf/swift-rfc-3986",
        "swift-compositions/swift-sqlite",
    ]

    /// The `institute` arguments of one strict source measurement.
    public static func arguments(
        repository: Swift.String,
        revision: Institute.Planner.Revision,
        root: Swift.String,
        xcode: Swift.String
    ) -> [Swift.String] {
        [
            "ci", "--", "source",
            "--exit-policy", "strict",
            "--repository", repository,
            "--revision", revision.description,
            "--root", root,
            "--xcode-application", xcode,
        ]
    }
}
