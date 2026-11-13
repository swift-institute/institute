extension Source.Repair.Staged {
    public struct File: Hashable, Sendable {
        // swift-linter:disable:next raw concept
        // REASON: a path inside the repository as Git lists it, with / on every platform, compared whole and written to the report's JSON; looked at Path and File.Path, which Win32 spells with \ and which add a parse that can fail.
        public let path: Swift.String
        public let contents: [UInt8]?

        // swift-linter:disable:next raw concept
        // REASON: a path inside the repository as Git lists it, with / on every platform, compared whole and written to the report's JSON; looked at Path and File.Path, which Win32 spells with \ and which add a parse that can fail.
        public init(path: Swift.String, contents: [UInt8]?) {
            self.path = path
            self.contents = contents
        }
    }
}
