public import Institute_Model

extension Institute.Planner {
    /// The consumer's `.institute-ci-planner`: every planner row ever
    /// adopted, in order, among blank and `#` comment lines. The last row
    /// for a revision and platform wins.
    public struct Ledger: Sendable {
        public let text: Swift.String
        public let rows: [Row]

        public init(text: Swift.String) throws(Institute.Planner.Error) {
            self.text = text
            self.rows = try Row.rows(in: text)
        }
    }
}

extension Institute.Planner.Ledger {
    /// The row the consumer uses for `revision` on `platform`.
    public func winner(
        _ revision: Institute.Planner.Revision,
        _ platform: Institute.Planner.Platform
    ) -> Institute.Planner.Row? {
        rows.last { $0.revision == revision && $0.platform == platform }
    }

    /// The file with `rows` appended verbatim, after everything it holds.
    public func appending(_ rows: [Institute.Planner.Row]) -> Swift.String {
        let base = text.isEmpty || text.hasSuffix("\n") ? text : text + "\n"
        return base + rows.map { $0.line + "\n" }.joined()
    }
}
