extension Source.Repair.Staged {
  public struct File: Hashable, Sendable {
    public let path: Swift.String
    public let contents: [UInt8]?

    public init(path: Swift.String, contents: [UInt8]?) {
      self.path = path
      self.contents = contents
    }
  }
}
