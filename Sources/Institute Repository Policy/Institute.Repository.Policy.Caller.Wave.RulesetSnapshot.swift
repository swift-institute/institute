public import Institute_Model
public import Byte
public import JSON

extension Institute.Repository.Policy.Caller.Wave {
    public struct RulesetSnapshot: Sendable, Equatable {
        private static let payloadKeys = [
            "name", "target", "enforcement", "bypass_actors", "conditions", "rules",
        ]

        public let repository: String
        public let id: Int64
        public let restore: [Byte]
        public let opened: [Byte]

        public init(
            repository: String,
            id: Int64,
            live: [Byte],
            canonical: [Byte],
            integrationID: Int64
        ) throws(Error) {
            let liveObject = try Self.members(live, label: "live ruleset")
            let canonicalObject = try Self.members(canonical, label: "canonical ruleset")
            let restoreObject = Dictionary(
                uniqueKeysWithValues: Self.payloadKeys.compactMap { key in
                    liveObject[key].map { (key, $0) }
                }
            )
            let expectedObject = Dictionary(
                uniqueKeysWithValues: Self.payloadKeys.compactMap { key in
                    canonicalObject[key].map { (key, $0) }
                }
            )
            let restore = Self.bytes(restoreObject)
            let expected = Self.bytes(expectedObject)
            guard restore == expected else {
                throw .ruleset(
                    "\(repository): protected-main read-back differs from canonical policy"
                )
            }
            var openedObject = restoreObject
            openedObject["bypass_actors"] = [
                [
                    "actor_id": .number(Int(integrationID)),
                    "actor_type": "Integration",
                    "bypass_mode": "always",
                ]
            ]
            self.repository = repository
            self.id = id
            self.restore = restore
            self.opened = Self.bytes(openedObject)
        }

        public func verifiesClosed(_ live: [Byte]) -> Bool {
            Self.matches(live, expected: restore)
        }

        public func verifiesOpened(_ live: [Byte]) -> Bool {
            Self.matches(live, expected: opened)
        }

        public static func normalized(_ live: [Byte]) throws(Error) -> [Byte] {
            let object = try Self.members(live, label: "ruleset")
            return Self.bytes(
                Dictionary(
                    uniqueKeysWithValues: payloadKeys.compactMap { key in
                        object[key].map { (key, $0) }
                    }
                )
            )
        }

        public static func matches(_ live: [Byte], expected: [Byte]) -> Bool {
            do throws(Error) {
                return try normalized(live) == normalized(expected)
            } catch {
                return false
            }
        }

        public static func containsIntegration(
            _ live: [Byte],
            integrationID: Int64
        ) -> Bool {
            do throws(Error) {
                let object = try Self.members(live, label: "ruleset")
                return Self.actors(object).contains {
                    Int64($0["actor_id"]) == integrationID
                        && Swift.String($0["actor_type"]) == "Integration"
                }
            } catch {
                return false
            }
        }

        public static func removingIntegration(
            _ live: [Byte],
            integrationID: Int64
        ) throws(Error) -> [Byte] {
            var object = try Self.members(live, label: "ruleset")
            object["bypass_actors"] = .array(
                Self.actors(object).filter {
                    Int64($0["actor_id"]) != integrationID
                        || Swift.String($0["actor_type"]) != "Integration"
                }
            )
            return try normalized(Self.bytes(object))
        }

        private static func actors(_ object: [Swift.String: JSON]) -> [JSON] {
            object["bypass_actors"]?.array ?? []
        }

        private static func members(
            _ bytes: [Byte],
            label: Swift.String
        ) throws(Error) -> [Swift.String: JSON] {
            let value: JSON
            do throws(JSON.Error) {
                value = try JSON.parse(bytes)
            } catch {
                throw .ruleset("\(label) did not decode: \(error)")
            }
            guard let object = value.dictionary else {
                throw .ruleset("\(label) is not a JSON object")
            }
            return object
        }

        private static func bytes(_ object: [Swift.String: JSON]) -> [Byte] {
            [Byte](
                JSON.object(object.map { ($0.key, $0.value) })
                    .serialize(sortKeys: true)
                    .utf8
            )
        }
    }
}

extension Institute.Repository.Policy.Caller.Wave.RulesetSnapshot: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        [
            "repository": value.repository.json,
            "id": value.id.json,
            "restore": Swift.String(value.restore).json,
            "opened": Swift.String(value.opened).json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        Self(
            repository: try Swift.String(json: json["repository"]),
            id: try Swift.Int64(json: json["id"]),
            restore: [Byte](try Swift.String(json: json["restore"]).utf8),
            opened: [Byte](try Swift.String(json: json["opened"]).utf8)
        )
    }

    private init(
        repository: Swift.String,
        id: Swift.Int64,
        restore: [Byte],
        opened: [Byte]
    ) {
        self.repository = repository
        self.id = id
        self.restore = restore
        self.opened = opened
    }
}
