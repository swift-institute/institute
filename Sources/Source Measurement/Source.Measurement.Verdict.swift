extension Source.Measurement {
    public enum Verdict: Sendable {
        case clean
        case findings([Source.Finding])
        case unmeasured([Source.Reason])
        case notRequested
    }
}
