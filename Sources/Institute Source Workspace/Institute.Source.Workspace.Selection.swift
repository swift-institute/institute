public import Institute_Model
public import Source_Measurement

extension Institute.Source.Workspace {
    public struct Selection: Sendable {
        public let rows: [Row]
        public let reasons: [Source.Reason]

        public init(
            rows: [Row],
            reasons: [Source.Reason]
        ) {
            self.rows = rows
            self.reasons = reasons
        }
    }
}
