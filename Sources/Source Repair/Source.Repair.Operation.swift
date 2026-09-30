extension Source.Repair {
  public enum Operation: Hashable, Sendable {
    case rewrite(path: Swift.String, expected: Swift.String, replacement: [UInt8])
    case create(path: Swift.String, contents: [UInt8])
    case move(from: Swift.String, to: Swift.String, expected: Swift.String)
    case delete(path: Swift.String, expected: Swift.String)
  }
}
