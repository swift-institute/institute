extension Source.Repair.Proposal {
    public struct Edit: Hashable, Sendable {
        // swift-linter:disable:next raw concept
        // REASON: the file as the engine named it, the subject's root, / and the artifact's path, compared by that prefix and written to the report; looked at Path and File.Path, which Win32 spells with \ and which add a parse that can fail.
        public let path: Swift.String
        public let expected: Swift.String
        public let replacement: [UInt8]

        // swift-linter:disable:next raw concept
        // REASON: the file as the engine named it, the subject's root, / and the artifact's path, compared by that prefix and written to the report; looked at Path and File.Path, which Win32 spells with \ and which add a parse that can fail.
        public init(path: Swift.String, expected: Swift.String, replacement: [UInt8]) {
            self.path = path
            self.expected = expected
            self.replacement = replacement
        }
    }
}
