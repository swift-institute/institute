import Byte
import FIPS_180_4
import Institute_Model

extension Institute.Planner {
    /// Reads a SHA-256 digest as the contract spells it: 64 lowercase
    /// hexadecimal characters.
    static func digest(_ text: some StringProtocol) throws(Error) -> FIPS_180_4.Digest {
        guard isHex(text, count: 64), let digest = FIPS_180_4.Digest(hex: Swift.String(text))
        else {
            throw .malformed(
                line: Swift.String(text),
                reason: "a digest is 64 lowercase hexadecimal characters"
            )
        }
        return digest
    }

    /// The SHA-256 digest of `bytes`.
    static func digest(of bytes: [Byte]) -> FIPS_180_4.Digest {
        FIPS_180_4.SHA256.digest(bytes)
    }
}
