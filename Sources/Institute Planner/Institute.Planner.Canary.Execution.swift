public import Institute_Model

extension Institute.Planner.Canary {
    /// What one planner run left behind: its exit code, `nil` when a
    /// signal ended it, and its standard output.
    public struct Execution: Sendable, Equatable {
        public let code: Swift.Int32?
        public let output: Swift.String

        public init(code: Swift.Int32?, output: Swift.String) {
            self.code = code
            self.output = output
        }
    }
}
