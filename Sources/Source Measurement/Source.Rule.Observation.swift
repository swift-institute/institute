extension Source.Rule {
    public struct Observation: Hashable, Sendable {
        // swift-linter:disable:next raw concept
        // REASON: the file a measurement covers, as the engine reported it and Source.Measurement.files lists it, compared whole against Source.Location.filePath and written to the measurement's JSON, where a file ID can stand for a path; looked at Path, which misdescribes a file ID and adds a parse that can fail.
        public let file: Swift.String
        public let rule: ID
        public let applicable: Swift.Bool
        public let coverage: Coverage

        public init(
            // swift-linter:disable:next raw concept
            // REASON: the file a measurement covers, as the engine reported it and Source.Measurement.files lists it, compared whole against Source.Location.filePath and written to the measurement's JSON, where a file ID can stand for a path; looked at Path, which misdescribes a file ID and adds a parse that can fail.
            file: Swift.String,
            rule: ID,
            applicable: Swift.Bool,
            coverage: Coverage
        ) {
            self.file = file
            self.rule = rule
            self.applicable = applicable
            self.coverage = coverage
        }
    }
}
