extension Source.Repair.Transaction {
  public struct Member: Sendable {
    public let plan: Source.Repair.Plan
    public let subject: Source.Subject.Binding
    public let profile: Source.Profile.Digest
    public let sources: Source.SourceSet.Digest
    public let files: Source.Repair.FileSystem

    public init(
      plan: Source.Repair.Plan,
      subject: Source.Subject.Binding,
      profile: Source.Profile.Digest,
      sources: Source.SourceSet.Digest,
      files: Source.Repair.FileSystem
    ) {
      self.plan = plan
      self.subject = subject
      self.profile = profile
      self.sources = sources
      self.files = files
    }
  }
}
