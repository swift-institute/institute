extension Repository.Policy.Caller.Wave {
    struct PreparedRuleset: Sendable, Equatable {
        let snapshot: RulesetSnapshot
        let changed: Bool
    }
}
