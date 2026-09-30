extension Source.Execution {
  /// The complete transitional source-measurement engine set.
  public init(process: Source.Engine.Process) throws(Error) {
    try self.init(
      drivers: [
        .swiftFormat(process: process),
        .swiftLint(process: process),
        .linter(process: process),
      ]
    )
  }
}
