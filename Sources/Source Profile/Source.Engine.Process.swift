extension Source.Engine {
  public struct Process: Sendable {
    public let run:
      @Sendable (
        _ executable: Swift.String,
        _ arguments: [Swift.String],
        _ directory: Swift.String,
        _ environment: [Swift.String: Swift.String]
      ) async -> Result

    public init(
      run:
        @escaping @Sendable (
          _ executable: Swift.String,
          _ arguments: [Swift.String],
          _ directory: Swift.String,
          _ environment: [Swift.String: Swift.String]
        ) async -> Result
    ) {
      self.run = run
    }
  }
}
