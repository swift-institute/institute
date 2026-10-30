extension Source.Profile {
    public struct Engine: Equatable, Sendable, JSON.Serializable {
        public let id: Source.Engine.ID
        public let executable: Swift.String
        public let tool: Digest
        public let configuration: Digest
        public let configurationPath: Swift.String
        public let environment: [Swift.String: Swift.String]
        public let artifactKinds: [Source.Artifact.Kind]
        public let rules: [Source.Rule.ID]

        public init(
            id: Source.Engine.ID,
            executable: Swift.String,
            tool: Digest,
            configuration: Digest,
            configurationPath: Swift.String,
            environment: [Swift.String: Swift.String] = [:],
            artifactKinds: [Source.Artifact.Kind],
            rules: [Source.Rule.ID]
        ) {
            self.id = id
            self.executable = executable
            self.tool = tool
            self.configuration = configuration
            self.configurationPath = configurationPath
            self.environment = environment
            self.artifactKinds = artifactKinds.sorted { $0.rawValue < $1.rawValue }
            self.rules = rules.sorted {
                ($0.engine.token, $0.token) < ($1.engine.token, $1.token)
            }
        }

        public static func serialize(_ value: Self) -> JSON {
            [
                "id": value.id.json,
                "executable": value.executable.json,
                "tool": value.tool.json,
                "configuration": value.configuration.json,
                "configurationPath": value.configurationPath.json,
                "environment": value.environment.json,
                "artifactKinds": value.artifactKinds.json,
                "rules": value.rules.json,
            ]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary else {
                throw .typeMismatch(expected: "object", got: "non-object")
            }
            let expected: Set<Swift.String> = [
                "id", "executable", "tool", "configuration", "configurationPath", "environment",
                "artifactKinds", "rules",
            ]
            guard Set(object.keys) == expected else {
                throw .typeMismatch(expected: "source profile engine keys", got: "foreign keys")
            }
            guard let id = object["id"] else { throw .missingKey("id") }
            guard let executable = object["executable"] else { throw .missingKey("executable") }
            guard let tool = object["tool"] else { throw .missingKey("tool") }
            guard let configuration = object["configuration"] else {
                throw .missingKey("configuration")
            }
            guard let configurationPath = object["configurationPath"] else {
                throw .missingKey("configurationPath")
            }
            guard let environment = object["environment"] else {
                throw .missingKey("environment")
            }
            guard let artifactKinds = object["artifactKinds"] else {
                throw .missingKey("artifactKinds")
            }
            guard let rules = object["rules"] else { throw .missingKey("rules") }
            return try Self(
                id: Source.Engine.ID(json: id),
                executable: Swift.String(json: executable),
                tool: Digest(json: tool),
                configuration: Digest(json: configuration),
                configurationPath: Swift.String(json: configurationPath),
                environment: [Swift.String: Swift.String](json: environment),
                artifactKinds: [Source.Artifact.Kind](json: artifactKinds),
                rules: [Source.Rule.ID](json: rules)
            )
        }
    }
}
