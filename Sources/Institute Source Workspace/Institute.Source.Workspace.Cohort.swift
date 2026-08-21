extension Institute.Source.Workspace {
    public struct Cohort: Sendable {
        public let workspace: Swift.String
        public let references: Swift.Int
        public let groupReferences: Swift.Int
        public let containerReferences: Swift.Int
        public let rows: [Row]
        public let reasons: [SourceDomain.Reason]

        public var admitted: [Row] {
            rows.filter {
                guard case .subject = $0.role else { return false }
                return $0.repository != nil && $0.reason == nil
            }
        }

        public var controls: [Row] {
            rows.filter {
                guard case .control = $0.role else { return false }
                return $0.reason == nil
            }
        }

        public init(
            workspace: Swift.String,
            references: Swift.Int,
            groupReferences: Swift.Int,
            containerReferences: Swift.Int,
            rows: [Row],
            reasons: [SourceDomain.Reason]
        ) {
            self.workspace = workspace
            self.references = references
            self.groupReferences = groupReferences
            self.containerReferences = containerReferences
            self.rows = rows
            self.reasons = reasons
        }
    }
}
