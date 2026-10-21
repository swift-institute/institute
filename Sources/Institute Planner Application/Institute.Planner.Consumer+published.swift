public import Institute_Model

extension Institute.Planner.Consumer {
    /// The live default branch of swift-institute/.github, read from its
    /// public raw-content host. It needs no credential, so it reads the same
    /// on a developer machine and on a hosted runner, like the `institute-ci`
    /// action does.
    public static var published: Self {
        .init { path throws(Institute.Planner.Error) in
            try Institute.Planner.Curl.get(
                "https://raw.githubusercontent.com/\(Institute.Planner.consumer)/main/\(path)"
            )
        }
    }
}
