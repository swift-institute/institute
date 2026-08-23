public import Institute_Source_Policy
public import Institute_Model
internal import Linter_Institute_Rules
internal import Linter_Primitives
internal import Linter_Primitives_Rules
internal import Linter_Standards_Rules
public import Source_Measurement
public import Source_Profile

extension Institute_Model.Institute.Source {
  public struct Profile: Sendable {
    public let policy: Institute.Source.Policy

    public init(
      policy: Institute.Source.Policy = .current
    ) {
      self.policy = policy
    }

    public func rules(
      for bundle: Institute.Source.Bundle
    ) -> [Source_Measurement.Source.Rule.ID] {
      let configurations: [Lint.Rule.Configuration]
      switch bundle {
      case .primitives: configurations = Lint.Rule.Bundle.primitives
      case .standards: configurations = Lint.Rule.Bundle.standards
      case .institute: configurations = Lint.Rule.Bundle.institute
      }
      let engine = Source_Measurement.Source.Engine.ID("swift-linter")
      return configurations.map {
        .init(engine: engine, token: $0.rule.id.underlying)
      }.sorted(by: { $0.token < $1.token })
    }
  }
}
