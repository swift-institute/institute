public import Institute_Model
public import Source_Measurement
internal import Source_Profile

extension Institute.Source.Application {
  static func swiftLintRules(
    executable: Swift.String,
    configuration: Swift.String,
    directory: Swift.String,
    process: Source_Measurement.Source.Engine.Process
  ) async throws(Institute.Error) -> [Source_Measurement.Source.Rule.ID] {
    let result = await process.run(
      executable,
      ["rules", "--config", configuration, "--enabled", "--config-only"],
      directory,
      [:]
    )
    guard result.status == 0, result.diagnostics.isEmpty else {
      throw .process("cannot inventory pinned SwiftLint rules: \(result.diagnostics)")
    }
    return try swiftLintRules(output: result.output)
  }

  static func swiftLintRules(
    output: Swift.String
  ) throws(Institute.Error) -> [Source_Measurement.Source.Rule.ID] {
    var tokens: Swift.Set<Swift.String> = []
    for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
      guard line.first?.isWhitespace == false else { continue }
      guard line.last == ":" else {
        throw .configuration("pinned SwiftLint returned a malformed rule inventory")
      }
      let token = Swift.String(line.dropLast())
      guard !token.isEmpty,
        token.allSatisfy({ $0.isLowercase || $0.isNumber || $0 == "_" }),
        tokens.insert(token).inserted
      else { throw .configuration("pinned SwiftLint returned a non-canonical rule inventory") }
    }
    guard !tokens.isEmpty else {
      throw .configuration("pinned SwiftLint returned an empty rule inventory")
    }
    let engine = Source_Measurement.Source.Engine.ID("swiftlint")
    return tokens.sorted().map { .init(engine: engine, token: $0) }
  }
}
