extension Source.Repair {
    public enum Capability: Hashable, Sendable {
        case automatic
        case guarded
        case transactional
        case unavailable(Source.Reason)
    }
}
