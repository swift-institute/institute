import Institute_GitHub
public import Institute_Model

extension Institute.Planner.Consumer {
    /// The live default branch of swift-institute/.github, read through `gh`.
    public static var github: Self {
        .init { path throws(Institute.Planner.Error) in
            do throws(Institute.GitHub.Release.Error) {
                return try Institute.GitHub.Contents.read(
                    repository: Institute.Planner.consumer,
                    path: path,
                    ref: "main"
                )
            } catch {
                if case .missing = error { throw .missing("\(Institute.Planner.consumer) \(path)") }
                throw .transport("cannot read \(path) from \(Institute.Planner.consumer): \(error)")
            }
        }
    }
}
