extension Source {
  public struct Subject: Hashable, Sendable {
    public let identity: Swift.String
    public let root: Swift.String
    public let artifacts: [Artifact]

    public init(identity: Swift.String, root: Swift.String, artifacts: [Artifact]) {
      self.identity = identity
      self.root = root
      self.artifacts = artifacts.sorted { $0.path < $1.path }
    }

    public func paths(of kind: Artifact.Kind) -> [Swift.String] {
      artifacts.lazy.filter { $0.kind == kind }.map(\.path)
    }
  }
}
