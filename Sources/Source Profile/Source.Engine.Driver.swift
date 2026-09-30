extension Source.Engine {
  public struct Driver: Sendable {
    public let id: ID
    public let measure:
      @Sendable (Source.Subject, Source.Profile.Engine) async -> Source.Measurement
    public let repair:
      @Sendable (Source.Subject, Source.Profile.Engine) async -> Source.Repair.Proposal

    public init(
      id: ID,
      measure:
        @escaping @Sendable (
          Source.Subject,
          Source.Profile.Engine
        ) async -> Source.Measurement,
      repair:
        @escaping @Sendable (
          Source.Subject,
          Source.Profile.Engine
        ) async -> Source.Repair.Proposal
    ) {
      self.id = id
      self.measure = measure
      self.repair = repair
    }
  }
}
