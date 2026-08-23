public import Institute_Model
public import Foundation

extension Institute.Repository.Policy.Caller.Wave {
    public struct RulesetSnapshot: Codable, Sendable, Equatable {
        private static let payloadKeys = [
            "name", "target", "enforcement", "bypass_actors", "conditions", "rules",
        ]

        public let repository: String
        public let id: Int64
        public let restore: Data
        public let opened: Data

        public init(
            repository: String,
            id: Int64,
            live: Data,
            canonical: Data,
            integrationID: Int64
        ) throws(Error) {
            let liveObject = try Self.object(live, label: "live ruleset")
            let canonicalObject = try Self.object(canonical, label: "canonical ruleset")
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
            let restore = try Self.data(restoreObject)
            let expected = try Self.data(expectedObject)
            guard restore == expected else {
                throw .ruleset(
                    "\(repository): protected-main read-back differs from canonical policy"
                )
            }
            var openedObject = restoreObject
            openedObject["bypass_actors"] = [
                [
                    "actor_id": integrationID,
                    "actor_type": "Integration",
                    "bypass_mode": "always",
                ]
            ]
            self.repository = repository
            self.id = id
            self.restore = restore
            self.opened = try Self.data(openedObject)
        }

        public func verifiesClosed(_ live: Data) -> Bool {
            Self.matches(live, expected: restore)
        }

        public func verifiesOpened(_ live: Data) -> Bool {
            Self.matches(live, expected: opened)
        }

        public static func normalized(_ live: Data) throws(Error) -> Data {
            let object = try Self.object(live, label: "ruleset")
            return try Self.data(
                Dictionary(
                    uniqueKeysWithValues: payloadKeys.compactMap { key in
                        object[key].map { (key, $0) }
                    }
                )
            )
        }

        public static func matches(_ live: Data, expected: Data) -> Bool {
            do throws(Error) {
                return try normalized(live) == normalized(expected)
            } catch {
                return false
            }
        }

        public static func containsIntegration(
            _ live: Data,
            integrationID: Int64
        ) -> Bool {
            do throws(Error) {
                let object = try Self.object(live, label: "ruleset")
                return Self.actors(object).contains {
                    ($0["actor_id"] as? NSNumber)?.int64Value == integrationID
                        && ($0["actor_type"] as? String) == "Integration"
                }
            } catch {
                return false
            }
        }

        public static func removingIntegration(
            _ live: Data,
            integrationID: Int64
        ) throws(Error) -> Data {
            var object = try Self.object(live, label: "ruleset")
            object["bypass_actors"] = Self.actors(object).filter {
                ($0["actor_id"] as? NSNumber)?.int64Value != integrationID
                    || ($0["actor_type"] as? String) != "Integration"
            }
            return try normalized(Self.data(object))
        }

        private static func actors(_ object: [String: Any]) -> [[String: Any]] {
            (object["bypass_actors"] as? [[String: Any]]) ?? []
        }

        private static func object(
            _ data: Data,
            label: String
        ) throws(Error) -> [String: Any] {
            do {
                guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                else {
                    throw Error.ruleset("\(label) is not a JSON object")
                }
                return object
            } catch let error as Institute.Repository.Policy.Caller.Wave.Error {
                throw error
            } catch {
                throw .ruleset("\(label) did not decode: \(error)")
            }
        }

        private static func data(_ object: [String: Any]) throws(Error) -> Data {
            do {
                return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            } catch {
                throw .ruleset("ruleset payload did not encode: \(error)")
            }
        }
    }
}
