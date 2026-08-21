public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Linter_Institute_Rules
public import Linter_Primitives_Rules
public import Linter_Standards_Rules
public import Source_Profile

extension Institute.Source {
    public struct Profile: Sendable {
        public let policy:
            Institute_Continuous_Integration_Source.Institute.ContinuousIntegration.Source.Policy

        public init(
            policy:
                Institute_Continuous_Integration_Source.Institute.ContinuousIntegration.Source.Policy = .current
        ) {
            self.policy = policy
        }

        public func rules(
            for bundle:
                Institute_Continuous_Integration_Source.Institute.ContinuousIntegration.Source.Bundle
        ) -> [Source_Profile.Source.Rule.ID] {
            let configurations: [Lint.Rule.Configuration]
            switch bundle {
            case .primitives: configurations = Lint.Rule.Bundle.primitives
            case .standards: configurations = Lint.Rule.Bundle.standards
            case .institute: configurations = Lint.Rule.Bundle.institute
            }
            let engine = Source_Profile.Source.Engine.ID("swift-linter")
            return configurations.map {
                .init(engine: engine, token: $0.rule.id.underlying)
            }.sorted(by: { $0.token < $1.token })
        }
    }
}
