public import Institute_Model
public import Source_Profile

extension Institute.Source.Policy {
    public struct Configuration: Sendable {
        public let engine: Source_Profile.Source.Engine.ID
        public let predicate: Source_Profile.Source.Rule.ID

        public init(
            engine: Source_Profile.Source.Engine.ID,
            predicate: Source_Profile.Source.Rule.ID
        ) {
            self.engine = engine
            self.predicate = predicate
        }
    }
}
