extension Source.Execution {
    public enum Error: Swift.Error, Sendable, Equatable {
        case duplicate(Source.Engine.ID)
    }
}
