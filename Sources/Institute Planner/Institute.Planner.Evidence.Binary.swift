import FIPS_180_4
public import Institute_Model
public import JSON

extension Institute.Planner.Evidence {
    /// One planner binary the canary ran: its row, digests and toolchain.
    public struct Binary: Sendable, Equatable, JSON.Serializable {
        public let row: Swift.String
        public let binary: Swift.String
        public let graph: Swift.String
        public let toolchain: Swift.String

        public init(row: Swift.String, binary: Swift.String, graph: Swift.String, toolchain: Swift.String) {
            self.row = row
            self.binary = binary
            self.graph = graph
            self.toolchain = toolchain
        }

        public init(_ executable: Institute.Planner.Executable) {
            self.init(
                row: executable.row.line,
                binary: executable.row.binary.hex,
                graph: executable.row.graph.hex,
                toolchain: executable.toolchain
            )
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "row": value.row.json,
                "binary": value.binary.json,
                "graph": value.graph.json,
                "toolchain": value.toolchain.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            .init(
                row: try Swift.String(json: json["row"]),
                binary: try Swift.String(json: json["binary"]),
                graph: try Swift.String(json: json["graph"]),
                toolchain: try Swift.String(json: json["toolchain"])
            )
        }
    }
}
