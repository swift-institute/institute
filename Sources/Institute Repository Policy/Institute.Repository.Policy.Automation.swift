public import Institute_Model

extension Institute.Repository.Policy {
    /// The automation of repositories, counted: what their `.github` runs that is not Swift, one row for each
    /// coordinate (a workflow, action or script file, a run block, an expression, a uses edge, a command a run
    /// block names). Written in the FT1-frozen sixteen-field schema that calls itself a census (censusVersion 1,
    /// the `institute repository census` verb); it is not the product census of packages, targets and types.
    /// Owns serialization; scanning lives in `Institute.Repository.Policy.Automation.Generator`.
    public struct Automation: Sendable, Equatable {
        public var rows: [Row]

        public init(rows: [Row]) {
            self.rows = rows
        }

        public static let fields: [String] = [
            "censusVersion", "repository", "headSha", "path",
            "coordinateKind", "coordinateId", "line", "engine",
            "excerptSha256", "family", "intendedOwner", "disposition",
            "measurement", "cause", "generatedBy", "notes",
        ]

        /// CSV bytes with minimal quoting and `\n` terminators — the exact
        /// dialect of the FT1 census artifact.
        public var csv: String {
            var out = Self.fields.map(Self.quoted).joined(separator: ",") + "\n"
            for row in rows {
                out += row.values.map(Self.quoted).joined(separator: ",") + "\n"
            }
            return out
        }

        /// Rows sorted by coordinate identity, for order-normalized parity
        /// between generators whose directory traversal order differs.
        public var normalized: Automation {
            Automation(
                rows: rows.sorted {
                    ($0.repository, $0.path, $0.coordinateId) < (
                        $1.repository, $1.path, $1.coordinateId
                    )
                }
            )
        }

        public static func quoted(_ field: String) -> String {
            guard
                field.contains(",") || field.contains("\"")
                    || field.contains("\n") || field.contains("\r")
            else {
                return field
            }
            return "\"" + field.replacing("\"", with: "\"\"") + "\""
        }
    }
}
