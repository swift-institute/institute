public import Institute_Model
public import Institute_Source_Policy
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
            policy.linterRules(for: bundle)
        }
    }
}
