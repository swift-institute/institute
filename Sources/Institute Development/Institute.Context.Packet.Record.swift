public import Institute_Inventory
public import Institute_Model

extension Institute.Context.Packet {
    public struct Record: Equatable, Sendable {
        public let key: Institute.Context.Packet.Key
        public let title: Swift.String
        public let state: Swift.String
        public let type: Swift.String
        public let stateReason: Swift.String?
        public let url: Swift.String
        public let body: Swift.String
        public let assignees: [Swift.String]
        public let labels: [Swift.String]
        public let parent: Swift.String?
        public let children: [Swift.String]
        public let comments: [Institute.Context.Packet.Record.Comment]
        public let divergences: [Swift.String]
        public let diagnostics: [Swift.String]
    }
}

extension Institute.Context.Packet.Record {
    public struct Comment: Equatable, Sendable {
        public let url: Swift.String
        public let issue: Institute.Context.Packet.Key
        public let author: Swift.String
        public let body: Swift.String
    }
}
