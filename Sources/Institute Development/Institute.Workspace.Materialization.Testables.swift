public import Institute_Model
public import JSON

extension Institute.Workspace.Materialization {
    public struct Testables: Sendable, Equatable, Institute.Receipt.Sealed {
        public let values: [Target]

        public init(values: [Target]) {
            self.values = values
        }

        public static func serialize(_ value: Self) -> JSON {
            ["values": value.values.json]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            try .init(values: [Target](json: json["values"]))
        }
    }
}
