public import Institute_Model

extension Institute.Planner {
    /// An exact institute-application commit as the contract spells it:
    /// 40 lowercase hexadecimal characters. Narrower than a git object id,
    /// which also admits uppercase and SHA-256 object names.
    public struct Revision: Hashable, Sendable, CustomStringConvertible {
        public let description: Swift.String

        public init(_ text: some StringProtocol) throws(Institute.Planner.Error) {
            guard Institute.Planner.isHex(text, count: 40) else {
                throw .malformed(
                    line: Swift.String(text),
                    reason: "a revision is 40 lowercase hexadecimal characters"
                )
            }
            self.description = Swift.String(text)
        }
    }
}
