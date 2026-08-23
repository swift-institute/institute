public import Institute_Model
public import Byte_Primitives
import Byte_Primitives_Standard_Library_Integration
public import JSON

extension Institute.Repository.Policy.Uniformity.Wave {
    /// One tracked file observed at an exact head: its blob identity and
    /// its exact bytes.
    public struct File: Sendable, Equatable {
        public let blob: String
        public let bytes: [Byte]

        public init(blob: String, bytes: [Byte]) {
            self.blob = blob
            self.bytes = bytes
        }
    }
}

extension Institute.Repository.Policy.Uniformity.Wave.File: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "blob": value.blob.json,
            "bytes": Swift.String(value.bytes).json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            blob: try Swift.String(json: json["blob"]),
            bytes: [Byte](try Swift.String(json: json["bytes"]).utf8)
        )
    }
}
