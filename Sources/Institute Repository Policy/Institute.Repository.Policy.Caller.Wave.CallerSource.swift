public import Institute_Model
public import Foundation

extension Institute.Repository.Policy.Caller.Wave {
    public struct CallerSource: Codable, Sendable, Equatable {
        public let blob: String
        public let bytes: Data

        public init(blob: String, bytes: Data) {
            self.blob = blob
            self.bytes = bytes
        }
    }
}
