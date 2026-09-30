public import Institute_Model
public import Byte

extension Institute.Repository.Policy.Caller.Wave.Recensus {
    public struct Evidence: Sendable {
        public let caller: [Byte]
        public let receipts: [Institute.Repository.Policy.Caller.Wave.Receipt]
        public let events: [Institute.Repository.Policy.Caller.Wave.Event]
        public let closures: [Institute.Repository.Policy.Caller.Wave.Closure]
        public let policyDigest: String
        public let policySource: String

        public init(
            caller: [Byte],
            receipts: [Institute.Repository.Policy.Caller.Wave.Receipt],
            events: [Institute.Repository.Policy.Caller.Wave.Event],
            closures: [Institute.Repository.Policy.Caller.Wave.Closure],
            policyDigest: String,
            policySource: String
        ) {
            self.caller = caller
            self.receipts = receipts
            self.events = events
            self.closures = closures
            self.policyDigest = policyDigest
            self.policySource = policySource
        }
    }
}
