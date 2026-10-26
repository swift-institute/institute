public import Institute_Model
public import JSON
public import Source_Repair

extension Institute.Source.Preparation {
    public enum Binding: Sendable, Equatable, JSON.Serializable {
        case package(Source_Repair.Source.Subject.Binding)

        public static func serialize(_ value: Self) -> JSON {
            switch value {
            case .package(let subject):
                ["kind": "package".json, "subject": subject.json]
            }
        }

        public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
            guard let object = json.dictionary, let kind = object["kind"] else {
                throw .typeMismatch(expected: "source preparation binding", got: "other")
            }
            switch try Swift.String(json: kind) {
            case "package":
                guard Set(object.keys) == ["kind", "subject"], let subject = object["subject"] else {
                    throw .typeMismatch(expected: "package source binding", got: "other")
                }
                return try .package(Source_Repair.Source.Subject.Binding(json: subject))
            default:
                throw .typeMismatch(expected: "package source binding", got: "other")
            }
        }
    }
}
