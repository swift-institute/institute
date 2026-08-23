public import Institute_Model

extension Institute.Repository.Policy.Caller.Wave {
    public struct Manifest: Codable, Sendable, Equatable {
        public let kind: String
        public let blob: String

        public init(kind: String, blob: String) {
            self.kind = kind
            self.blob = blob
        }
    }
}
