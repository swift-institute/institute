public import Institute_Model

extension Institute.Planner {
    /// The consumer's `.institute-ci-pin`: exactly one revision line, and
    /// any number of blank and `#` comment lines, which are kept verbatim.
    public struct Pin: Sendable {
        public let text: Swift.String
        public let revision: Revision

        public init(text: Swift.String) throws(Institute.Planner.Error) {
            let entries = Institute.Planner.entries(text)
            guard entries.count == 1, let entry = entries.first else {
                throw .malformed(
                    line: entries.joined(separator: " | "),
                    reason: ".institute-ci-pin must hold exactly one revision line"
                )
            }
            self.text = text
            self.revision = try Revision(entry)
        }
    }
}

extension Institute.Planner.Pin {
    /// The file pinning `revision` instead: the revision line replaced,
    /// every other line kept in place.
    public func pinning(_ revision: Institute.Planner.Revision) -> Swift.String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            Institute.Planner.entries(Swift.String(line)).isEmpty
                ? Swift.String(line) : revision.description
        }
        return lines.joined(separator: "\n")
    }
}
