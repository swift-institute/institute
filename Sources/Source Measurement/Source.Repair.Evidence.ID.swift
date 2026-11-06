extension Source.Repair.Evidence {
    public struct ID: Hashable, Sendable {
        // swift-linter:disable:next raw concept
        // REASON: the file a measurement covers, as the engine reported it and Source.Measurement.files lists it, compared whole against Source.Location.filePath and written to the measurement's JSON, where a file ID can stand for a path; looked at Path, which misdescribes a file ID and adds a parse that can fail.
        public let file: Swift.String
        public let rule: Source.Rule.ID

        // swift-linter:disable:next raw concept
        // REASON: the file a measurement covers, as the engine reported it and Source.Measurement.files lists it, compared whole against Source.Location.filePath and written to the measurement's JSON, where a file ID can stand for a path; looked at Path, which misdescribes a file ID and adds a parse that can fail.
        public init(file: Swift.String, rule: Source.Rule.ID) {
            self.file = file
            self.rule = rule
        }
    }
}

extension Source.Repair.Evidence {
    public var id: ID { .init(file: file, rule: rule) }
}
