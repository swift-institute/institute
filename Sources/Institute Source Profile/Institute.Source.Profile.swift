public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Source_Profile

extension Institute.Source {
    public struct Profile: Sendable {
        public let policy: Institute.ContinuousIntegration.Source.Policy

        public init(
            policy: Institute.ContinuousIntegration.Source.Policy = .current
        ) {
            self.policy = policy
        }
    }
}
