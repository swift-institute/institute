public import FIPS_180_4
public import Institute_Model

extension Institute.Planner {
    /// One planner row, `<revision> <platform> <binary sha256> <graph sha256>`,
    /// as a PIN asset publishes it and `.institute-ci-planner` records it.
    ///
    /// The row keeps its line verbatim: admissibility is decided by exact
    /// line equality with a published PIN line, never by equal fields, so a
    /// row re-spelled with other whitespace is a different, unpublished row.
    public struct Row: Hashable, Sendable {
        public let revision: Revision
        public let platform: Platform
        public let binary: FIPS_180_4.Digest
        public let graph: FIPS_180_4.Digest
        public let line: Swift.String

        public init(line: some StringProtocol) throws(Institute.Planner.Error) {
            let text = Swift.String(line)
            let fields = text.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard fields.count == 4 else {
                throw .malformed(
                    line: text,
                    reason: "a planner row is exactly <revision> <platform> <binary> <graph>"
                )
            }
            let revision = try Revision(fields[0])
            guard let platform = Platform(rawValue: Swift.String(fields[1])) else {
                throw .platform(Swift.String(fields[1]))
            }
            self.revision = revision
            self.platform = platform
            self.binary = try Institute.Planner.digest(fields[2])
            self.graph = try Institute.Planner.digest(fields[3])
            self.line = text
        }
    }
}

extension Institute.Planner.Row {
    /// Every row of a PIN asset or planner file, in order. Blank and `#`
    /// lines are skipped; any other line must be a row.
    public static func rows(in text: Swift.String) throws(Institute.Planner.Error) -> [Self] {
        try Institute.Planner.entries(text).map { line throws(Institute.Planner.Error) in
            try Self(line: line)
        }
    }
}
