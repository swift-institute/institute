public import JSON

extension Institute.Workspace {
    public struct Specification: Sendable, Equatable, JSON.Serializable {
        public static let schema = 1

        public let members: [Member]

        public init(members: [Member]) {
            self.members = members
        }

        public static func serialize(_ value: Self) -> JSON {
            ["schema": schema.json, "members": value.members.json]
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary,
                Set(object.keys) == ["schema", "members"],
                let schemaValue = object["schema"],
                let membersValue = object["members"]
            else {
                throw .typeMismatch(expected: "workspace specification", got: "other JSON")
            }
            guard try Swift.Int(json: schemaValue) == schema else {
                throw .typeMismatch(expected: "workspace schema 1", got: "other schema")
            }
            let members = try [Member](json: membersValue)
            guard Set(members.map(\.location)).count == members.count else {
                throw .typeMismatch(expected: "unique workspace locations", got: "duplicates")
            }
            let subjects = members.compactMap { member -> Institute.Repository.Key? in
                guard case .subject(let repository) = member.role else { return nil }
                return repository
            }
            guard Set(subjects).count == subjects.count else {
                throw .typeMismatch(expected: "unique workspace subjects", got: "duplicates")
            }
            let controls = members.compactMap { member -> Control? in
                guard case .control(let control) = member.role else { return nil }
                return control
            }
            guard Set(controls.map(\.rawValue)).count == controls.count else {
                throw .typeMismatch(expected: "unique workspace controls", got: "duplicates")
            }
            return .init(members: members)
        }
    }
}
