public import Institute_Model
public import Foundation

extension Institute.Repository.Policy.Uniformity.Wave.Recensus {
    public struct Evidence: Sendable {
        public let payload: Data
        public let receipts: [Institute.Repository.Policy.Uniformity.Wave.Receipt]
        public let events: [Institute.Repository.Policy.Uniformity.Wave.Event]
        public let closures: [Institute.Repository.Policy.Uniformity.Wave.Closure]
        public let policyDigest: String
        public let policySource: String

        public init(
            payload: Data,
            receipts: [Institute.Repository.Policy.Uniformity.Wave.Receipt],
            events: [Institute.Repository.Policy.Uniformity.Wave.Event],
            closures: [Institute.Repository.Policy.Uniformity.Wave.Closure],
            policyDigest: String,
            policySource: String
        ) {
            self.payload = payload
            self.receipts = receipts
            self.events = events
            self.closures = closures
            self.policyDigest = policyDigest
            self.policySource = policySource
        }
    }
}
