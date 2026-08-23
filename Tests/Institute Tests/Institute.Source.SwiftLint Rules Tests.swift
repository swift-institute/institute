import Institute_Model
import Testing

@testable import Institute_Source

@Test
func `SwiftLint inventory admits only canonical top level rule identities`() throws {
  let rules = try Institute.Source.Application.swiftLintRules(
    output: """
      empty_count:
        severity: error
      identifier_name:
        min_length: 3
      """
  )
  #expect(rules.map(\.token) == ["empty_count", "identifier_name"])
  #expect(rules.allSatisfy { $0.engine == .init("swiftlint") })
}

@Test
func `SwiftLint inventory refuses duplicate rule identities`() {
  #expect(throws: Institute.Error.self) {
    try Institute.Source.Application.swiftLintRules(
      output: "duplicate_imports:\nduplicate_imports:\n"
    )
  }
}
