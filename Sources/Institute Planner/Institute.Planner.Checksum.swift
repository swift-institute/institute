public import FIPS_180_4
public import Institute_Model

extension Institute.Planner {
    /// One `sha256sum` line of a SHA256SUMS asset: a digest, a separator
    /// space, a mode marker (space for text, `*` for binary), and the
    /// asset name.
    public struct Checksum: Hashable, Sendable {
        public let digest: FIPS_180_4.Digest
        public let name: Swift.String

        public init(line: some StringProtocol) throws(Institute.Planner.Error) {
            let text = Swift.String(line)
            let utf8 = Array(text.utf8)
            guard utf8.count > 66, utf8[64] == 0x20, utf8[65] == 0x20 || utf8[65] == 0x2A
            else {
                throw .malformed(line: text, reason: "a checksum line is <sha256>  <name>")
            }
            let name = Swift.String(decoding: utf8[66...], as: Swift.UTF8.self)
            guard !name.contains(where: { $0 == " " || $0 == "\t" || $0 == "/" }) else {
                throw .malformed(line: text, reason: "an asset name is one path component")
            }
            self.digest = try Institute.Planner.digest(text.prefix(64))
            self.name = name
        }
    }
}

extension Institute.Planner.Checksum {
    /// Every line of a SHA256SUMS asset, refusing a name listed twice.
    public static func checksums(
        in text: Swift.String
    ) throws(Institute.Planner.Error) -> [Swift.String: FIPS_180_4.Digest] {
        var checksums: [Swift.String: FIPS_180_4.Digest] = [:]
        for line in text.split(separator: "\n") {
            let checksum = try Self(line: line)
            guard checksums.updateValue(checksum.digest, forKey: checksum.name) == nil else {
                throw .ambiguous("checksum for \(checksum.name)")
            }
        }
        return checksums
    }
}
