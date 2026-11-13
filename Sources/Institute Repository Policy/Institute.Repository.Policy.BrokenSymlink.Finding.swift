public import Institute_Model

extension Institute.Repository.Policy.BrokenSymlink {
    public struct Finding: Sendable, Hashable {
        // swift-linter:disable:next raw concept
        // REASON: a path inside a repository as GitHub and Git name it, with / on every platform, compared as text and put into API routes; looked at File.Path, which Win32 spells with \ and which adds a parse that can fail.
        public let path: Swift.String

        // swift-linter:disable:next raw concept
        // REASON: a path inside a repository as GitHub and Git name it, with / on every platform, compared as text and put into API routes; looked at File.Path, which Win32 spells with \ and which adds a parse that can fail.
        public init(path: Swift.String) {
            self.path = path
        }
    }
}
