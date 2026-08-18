public import Institute_Model
public import JSON

extension Institute.Certification.Member {
    /// What obligations a snapshot member carries.
    ///
    /// The certification population is not homogeneous: the 462-repository
    /// package inventory carries package build/test/platform obligations,
    /// while the seven central governance/control-plane repositories are
    /// exact-revision members whose obligations are typed separately and
    /// are never silently assumed to be package obligations (the 462+7=469
    /// boundary recorded on `swift-institute/.github#600`, 2026-08-18).
    public enum Kind: Equatable, Hashable, Sendable, JSON.Serializable {
        /// An inventory package member, at its inventory layer.
        case package(layer: Institute.Layer)

        /// A central governance or control-plane member — present in the
        /// snapshot by exact revision, classified further by
        /// `swift-institute/.github#627`, and never carrying implied
        /// package obligations.
        case controlPlane
    }
}

extension Institute.Certification.Member.Kind {
    public static func serialize(_ value: Self) -> JSON {
        switch value {
        case .package(let layer):
            ["package": layer.json]

        case .controlPlane:
            "control-plane".json
        }
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        if let object = json.dictionary {
            guard object.count == 1, let layer = object["package"] else {
                throw .typeMismatch(
                    expected: "member kind object with single package key",
                    got: object.keys.sorted().joined(separator: ", ")
                )
            }
            return try .package(layer: Institute.Layer(json: layer))
        }
        let value = try Swift.String(json: json)
        guard value == "control-plane" else {
            throw .typeMismatch(expected: "control-plane", got: value)
        }
        return .controlPlane
    }
}
