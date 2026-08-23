public import Institute_Model
import Byte_Primitives
import FIPS_180_4
public import Foundation

extension Institute.Repository.Policy.Caller.Wave {
    static func digest(_ values: [String]) -> String {
        var bytes: [UInt8] = []
        for value in values {
            bytes.append(contentsOf: value.utf8)
            bytes.append(0)
        }
        return FIPS_180_4.SHA256.digest(bytes.map(Byte.init)).hex
    }

    public static func digest(_ data: Data) -> String {
        FIPS_180_4.SHA256.digest([UInt8](data).map(Byte.init)).hex
    }

    static func stableData<T: Encodable>(_ value: T) throws(Error) -> Data {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            return try encoder.encode(value)
        } catch {
            throw .verification("transaction evidence did not encode: \(error)")
        }
    }

    /// The exact bytes an evidence file carries on disk. Digests recorded in
    /// receipts refer to these bytes, so independent verifiers can compare a
    /// file checksum against a recorded digest without re-encoding.
    public static func evidenceData<T: Encodable>(_ value: T) throws(Error) -> Data {
        var data = try stableData(value)
        data.append(0x0A)
        return data
    }
}
