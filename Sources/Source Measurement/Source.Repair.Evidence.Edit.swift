extension Source.Repair.Evidence {
  public enum Edit: Hashable, Sendable {
    case rewrite(path: Swift.String, contents: Swift.String)
    case create(path: Swift.String, contents: Swift.String)
    case move(from: Swift.String, to: Swift.String)
    case delete(path: Swift.String)
  }
}
