public import Institute_Model
public import JSON

extension Institute.Workspace.Materialization {
    public struct Input: Sendable, Equatable, Institute.Receipt.Sealed {
        public let toolchain: Swift.String
        public let packages: [Package]

        public init(toolchain: Swift.String, packages: [Package]) {
            self.toolchain = toolchain
            self.packages = packages
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "toolchain": value.toolchain.json,
                "packages": value.packages.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            try .init(
                toolchain: Swift.String(json: json["toolchain"]),
                packages: [Package](json: json["packages"])
            )
        }
    }
}
