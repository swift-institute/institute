public import Institute_Model
public import Foundation

extension Institute.Repository.Policy.Uniformity.Wave {
    /// One tracked file observed at an exact head: its blob identity and
    /// its exact bytes.
    public struct File: Codable, Sendable, Equatable {
        public let blob: String
        public let bytes: Data

        public init(blob: String, bytes: Data) {
            self.blob = blob
            self.bytes = bytes
        }
    }
}
