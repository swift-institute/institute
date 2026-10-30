extension Source.Report.Complete {
    public enum Error: Swift.Error, Sendable, Equatable {
        case partial
        case references
        case commitment
        case subjects
        case engines(Swift.String)
        case coverage(Swift.String)
        case artifacts(Swift.String)
    }
}
