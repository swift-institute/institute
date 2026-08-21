public import JSON

extension Institute.Workspace.Role: JSON.Serializable {
    public static func serialize(_ value: Self) -> JSON {
        switch value {
        case .subject(let repository):
            return ["kind": "subject", "repository": repository.json]
        case .control(let control):
            return ["kind": "control", "control": control.rawValue.json]
        }
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary, let kind = object["kind"] else {
            throw .typeMismatch(expected: "workspace role object", got: "other JSON")
        }
        switch try Swift.String(json: kind) {
        case "subject":
            guard Set(object.keys) == ["kind", "repository"],
                let repository = object["repository"]
            else {
                throw .typeMismatch(
                    expected: "subject workspace role",
                    got: object.keys.sorted().joined(separator: ",")
                )
            }
            return try .subject(.init(json: repository))
        case "control":
            guard Set(object.keys) == ["kind", "control"],
                let value = object["control"],
                let control = Institute.Workspace.Control(
                    rawValue: try Swift.String(json: value)
                )
            else {
                throw .typeMismatch(
                    expected: "control workspace role",
                    got: object.keys.sorted().joined(separator: ",")
                )
            }
            return .control(control)
        default:
            throw .typeMismatch(expected: "subject|control", got: try Swift.String(json: kind))
        }
    }
}
