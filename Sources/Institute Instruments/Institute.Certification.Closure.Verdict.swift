public import Institute_Model
public import JSON

extension Institute.Certification.Closure {
    /// What one governed dependency edge's resolution proves.
    public enum Verdict: Equatable, Sendable, JSON.Serializable {
        /// A managed checkout at exactly the snapshot member revision.
        case exact(Institute.Repository.Key)

        /// A local path for an admitted member, in an evaluation that
        /// accepts local materialization.
        case local(Institute.Repository.Key)

        /// An edge to a typed-excluded member — lawful only because the
        /// exclusion is explicit in the addressed snapshot; consumers of
        /// an excluded member surface through the exclusion's own record.
        case excludedMember(Institute.Repository.Key)

        /// In a governed organization but not an admitted member — the
        /// swift-tls class (institute-application#212). Fails closed.
        case ungoverned(Institute.Repository.Key)

        /// An admitted member resolved at a different revision than the
        /// snapshot certifies.
        case revisionSkew(
            Institute.Repository.Key,
            resolved: Swift.String,
            member: Swift.String
        )

        /// A managed checkout where the evaluation required local
        /// materialization.
        case networkEscape(Institute.Repository.Key)

        /// A local path where the evaluation required managed checkouts.
        case unexpectedLocal(Institute.Repository.Key)

        /// A governed-organization location that does not parse as a
        /// canonical repository key.
        case unclassifiable
    }
}

extension Institute.Certification.Closure.Verdict {
    public static func serialize(_ value: Self) -> JSON {
        switch value {
        case .exact(let key):
            ["exact": key.json]

        case .local(let key):
            ["local": key.json]

        case .excludedMember(let key):
            ["excludedMember": key.json]

        case .ungoverned(let key):
            ["ungoverned": key.json]

        case .revisionSkew(let key, let resolved, let member):
            [
                "revisionSkew": [
                    "key": key.json,
                    "resolved": resolved.json,
                    "member": member.json,
                ]
            ]

        case .networkEscape(let key):
            ["networkEscape": key.json]

        case .unexpectedLocal(let key):
            ["unexpectedLocal": key.json]

        case .unclassifiable:
            "unclassifiable".json
        }
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        if json.dictionary == nil {
            let value = try Swift.String(json: json)
            guard value == "unclassifiable" else {
                throw .typeMismatch(expected: "unclassifiable", got: value)
            }
            return .unclassifiable
        }
        guard let object = json.dictionary, object.count == 1,
            let (name, payload) = object.first
        else {
            throw .typeMismatch(expected: "single-key verdict object", got: "other")
        }
        switch name {
        case "exact":
            return try .exact(Institute.Repository.Key(json: payload))

        case "local":
            return try .local(Institute.Repository.Key(json: payload))

        case "excludedMember":
            return try .excludedMember(Institute.Repository.Key(json: payload))

        case "ungoverned":
            return try .ungoverned(Institute.Repository.Key(json: payload))

        case "revisionSkew":
            guard let fields = payload.dictionary else {
                throw .typeMismatch(expected: "revisionSkew object", got: "non-object")
            }
            guard let key = fields["key"] else { throw .missingKey("key") }
            guard let resolved = fields["resolved"] else { throw .missingKey("resolved") }
            guard let member = fields["member"] else { throw .missingKey("member") }
            return try .revisionSkew(
                Institute.Repository.Key(json: key),
                resolved: Swift.String(json: resolved),
                member: Swift.String(json: member)
            )

        case "networkEscape":
            return try .networkEscape(Institute.Repository.Key(json: payload))

        case "unexpectedLocal":
            return try .unexpectedLocal(Institute.Repository.Key(json: payload))

        default:
            throw .typeMismatch(expected: "closure verdict", got: name)
        }
    }
}
