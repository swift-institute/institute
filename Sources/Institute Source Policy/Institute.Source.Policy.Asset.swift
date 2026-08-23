public import Institute_Model
public import Source_Profile

extension Institute.Source.Policy {
    public struct Asset: Sendable {
        public let name: Swift.String
        public let digest: Source_Profile.Source.Profile.Digest
        public let origin: Origin

        public init(
            name: Swift.String,
            digest: Source_Profile.Source.Profile.Digest,
            origin: Origin
        ) {
            precondition(!name.isEmpty)
            self.name = name
            self.digest = digest
            self.origin = origin
        }
    }
}
