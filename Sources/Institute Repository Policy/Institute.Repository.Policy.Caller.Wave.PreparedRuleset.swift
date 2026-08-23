public import Institute_Model

extension Institute.Repository.Policy.Caller.Wave {
    struct PreparedRuleset: Sendable, Equatable {
        let snapshot: RulesetSnapshot
        let changed: Bool
    }
}
