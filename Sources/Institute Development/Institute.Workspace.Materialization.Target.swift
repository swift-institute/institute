public import Institute_Model
public import JSON

extension Institute.Workspace.Materialization {
    public struct Target: Sendable, Equatable, JSON.Serializable {
        public let reference: Swift.String
        public let name: Swift.String

        public init(reference: Swift.String, name: Swift.String) {
            self.reference = reference
            self.name = name
        }

        public static func serialize(_ value: Self) -> JSON {
            ["reference": value.reference.json, "name": value.name.json]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            try .init(
                reference: Swift.String(json: json["reference"]),
                name: Swift.String(json: json["name"])
            )
        }
    }
}
