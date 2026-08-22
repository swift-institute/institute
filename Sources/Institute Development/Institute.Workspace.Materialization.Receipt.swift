public import File_System
public import Institute_Model
public import JSON

extension Institute.Workspace.Materialization {
    public struct Receipt: Sendable, Equatable, JSON.Serializable {
        public static let schema = 1

        public let input: Input
        public let artifacts: [Artifact]
        public let buildables: [Target]
        public let testables: Testables

        public init(
            input: Input,
            artifacts: [Artifact],
            buildables: [Target],
            testables: Testables
        ) {
            self.input = input
            self.artifacts = artifacts
            self.buildables = buildables
            self.testables = testables
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "schema": schema.json,
                "input": value.input.json,
                "inputDigest": value.input.digest.json,
                "artifacts": value.artifacts.json,
                "buildables": value.buildables.json,
                "testables": value.testables.json,
                "testablesDigest": value.testables.digest.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard try Swift.Int(json: json["schema"]) == schema else {
                throw .typeMismatch(expected: "materialization receipt schema 1", got: "other")
            }
            let input = try Input(json: json["input"])
            guard try Swift.String(json: json["inputDigest"]) == input.digest else {
                throw .typeMismatch(expected: "exact materialization input digest", got: "other")
            }
            let testables = try Testables(json: json["testables"])
            guard try Swift.String(json: json["testablesDigest"]) == testables.digest else {
                throw .typeMismatch(
                    expected: "exact materialization testables digest", got: "other")
            }
            return try .init(
                input: input,
                artifacts: [Artifact](json: json["artifacts"]),
                buildables: [Target](json: json["buildables"]),
                testables: testables
            )
        }
    }

    public static func receiptPath(at root: Institute.Root) -> File {
        Institute.Xcode.bundle(at: root.checkout)[directory: "xcshareddata"][
            file: "Institute.materialization.json"
        ]
    }
}
