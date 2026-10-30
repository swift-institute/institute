extension Source.Repair.Evidence {
    public enum Disposition: Hashable, Sendable {
        case unchanged
        case edits([Edit])
        case refused(Source.Reason)
    }
}
