public import Institute_Model
public import Byte_Primitives
import Byte_Primitives_Standard_Library_Integration
import FIPS_180_4
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    static func digest(_ values: [String]) -> String {
        var bytes: [Byte] = []
        for value in values {
            bytes.append(contentsOf: [Byte](value.utf8))
            bytes.append(Byte(0))
        }
        return FIPS_180_4.SHA256.digest(bytes).hex
    }

    public static func digest(_ bytes: [Byte]) -> String {
        FIPS_180_4.SHA256.digest(bytes).hex
    }

    static func stableBytes<T: JSON.Serializable>(_ value: T) -> [Byte] {
        [Byte](value.jsonString(sortKeys: true).utf8)
    }

    /// The exact bytes an evidence file carries on disk. Digests recorded in
    /// receipts refer to these bytes, so independent verifiers can compare a
    /// file checksum against a recorded digest without re-encoding.
    public static func evidenceBytes<T: JSON.Serializable>(_ value: T) -> [Byte] {
        var bytes = stableBytes(value)
        bytes.append(Byte(0x0A))
        return bytes
    }
}
