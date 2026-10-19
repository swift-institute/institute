public import Institute_Architecture_Model
public import Institute_Model

extension Institute.Architecture.Migration {
    /// The durable record of one epoch's classification.
    public struct Receipt: Sendable, Equatable {
        public let epoch: Institute.Architecture.Epoch.Identifier
        public let owner: Institute.Architecture.Owner
        public let phase: Phase
        public let consumers: [Institute.Architecture.Owner]

        public init(
            epoch: Institute.Architecture.Epoch.Identifier,
            owner: Institute.Architecture.Owner,
            phase: Phase,
            consumers: [Institute.Architecture.Owner]
        ) {
            self.epoch = epoch
            self.owner = owner
            self.phase = phase
            self.consumers = consumers
        }
    }
}
