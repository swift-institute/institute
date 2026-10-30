extension Source.Repair {
    public struct Proposal: Sendable {
        public let edits: [Edit]
        public let refusals: [Source.Reason]

        public init(edits: [Edit], refusals: [Source.Reason] = []) {
            self.edits = edits
            self.refusals = refusals
        }
    }
}
