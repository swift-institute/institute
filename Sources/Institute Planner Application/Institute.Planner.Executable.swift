public import Byte
public import Institute_Model

extension Institute.Planner {
    /// A published planner for one platform, verified: the row naming it,
    /// the binary's bytes, and the toolchain record it was built with.
    public struct Executable: Sendable {
        public let row: Row
        public let binary: [Byte]
        public let toolchain: Swift.String

        public init(row: Row, binary: [Byte], toolchain: Swift.String) {
            self.row = row
            self.binary = binary
            self.toolchain = toolchain
        }
    }
}
