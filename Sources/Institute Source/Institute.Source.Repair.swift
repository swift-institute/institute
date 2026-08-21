public import Institute_Model
public import JSON
public import Source_Repair

extension Institute.Source {
    public enum Repair {}
}

extension Institute.Source.Repair {
    public struct Plan: Sendable, JSON.Serializable {
        public static let schema = 1

        public let workspace: Swift.String
        public let workspaceDigest: Swift.String
        public let inventoryDigest: Swift.String
        public let cohort: [Swift.String]
        public let repair: SourceDomain.Repair.Plan

        public init(
            workspace: Swift.String,
            workspaceDigest: Swift.String,
            inventoryDigest: Swift.String,
            cohort: [Swift.String],
            repair: SourceDomain.Repair.Plan
        ) {
            self.workspace = workspace
            self.workspaceDigest = workspaceDigest
            self.inventoryDigest = inventoryDigest
            self.cohort = cohort
            self.repair = repair
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "schema": schema.json,
                "workspace": value.workspace.json,
                "workspaceDigest": value.workspaceDigest.json,
                "inventoryDigest": value.inventoryDigest.json,
                "cohort": value.cohort.json,
                "repair": value.repair.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            let expected: Set<Swift.String> = [
                "schema", "workspace", "workspaceDigest", "inventoryDigest", "cohort", "repair",
            ]
            guard Set(object.keys) == expected else {
                throw .typeMismatch(
                    expected: expected.sorted().joined(separator: ","),
                    got: object.keys.sorted().joined(separator: ",")
                )
            }
            func required(_ key: Swift.String) throws(JSON.Error) -> JSON {
                guard let value = object[key] else { throw .missingKey(key) }
                return value
            }
            guard try Swift.Int(json: required("schema")) == schema else {
                throw .typeMismatch(expected: "Institute source repair schema 1", got: "other schema")
            }
            return try .init(
                workspace: Swift.String(json: required("workspace")),
                workspaceDigest: Swift.String(json: required("workspaceDigest")),
                inventoryDigest: Swift.String(json: required("inventoryDigest")),
                cohort: [Swift.String](json: required("cohort")),
                repair: SourceDomain.Repair.Plan(json: required("repair"))
            )
        }
    }
}
