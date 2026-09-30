extension Source.Engine.Process {
  public struct Result: Sendable {
    public let status: Swift.Int32
    public let output: Swift.String
    public let diagnostics: Swift.String

    public init(status: Swift.Int32, output: Swift.String, diagnostics: Swift.String) {
      self.status = status
      self.output = output
      self.diagnostics = diagnostics
    }
  }
}
