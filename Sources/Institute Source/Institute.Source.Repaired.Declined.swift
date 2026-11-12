public import Institute_Model

extension Institute.Source.Repaired {
    public struct Declined: Sendable, Equatable {
        // swift-linter:disable:next raw concept
        // REASON: what a repair was declined for, as the report prints it: a file relative to the package root, or whatever else the engine's refusal names; looked at Path, which a refusal's detail need not be.
        public let file: Swift.String
        public let reason: Swift.String

        // swift-linter:disable:next raw concept
        // REASON: what a repair was declined for, as the report prints it: a file relative to the package root, or whatever else the engine's refusal names; looked at Path, which a refusal's detail need not be.
        public init(file: Swift.String, reason: Swift.String) {
            self.file = file
            self.reason = reason
        }
    }
}
