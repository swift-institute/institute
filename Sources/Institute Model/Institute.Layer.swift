public import JSON

extension Institute {
    /// The four Institute layers, one root organization each, in dependency order.
    ///
    /// They follow `swift-institute/.github`'s `.github/policy/fleet.json`: L1 `swift-atoms`, L2
    /// `swift-molecules`, L3 `swift-standards` (with the specification authorities and vendors nested
    /// under it), L4 `swift-compositions`. A package depends only on its own layer and the layers
    /// below it.
    public enum Layer: Swift.String, Swift.CaseIterable, Sendable, JSON.Serializable {
        case atoms
        case molecules
        case standards
        case compositions
    }
}

extension Institute.Layer {
    /// The stable inventory wire token owned by this enum.
    public var token: Swift.String { rawValue }

    /// The GitHub organization that is this layer's root: the directory
    /// a layer's packages materialize under, and the organization whose
    /// repositories sit directly in it. Organizations that are not a
    /// layer root — specification authorities, vendors, jurisdictions —
    /// nest under their layer's root per ruling 139.
    public var organization: Swift.String {
        switch self {
        case .atoms: "swift-atoms"
        case .molecules: "swift-molecules"
        case .standards: "swift-standards"
        case .compositions: "swift-compositions"
        }
    }

    package var order: Int {
        switch self {
        case .atoms: 1
        case .molecules: 2
        case .standards: 3
        case .compositions: 4
        }
    }

    public static func serialize(_ value: Self) -> JSON {
        value.token.json
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        let value = try Swift.String(json: json)
        guard let layer = Self(rawValue: value) else {
            throw .typeMismatch(expected: "Institute layer", got: value)
        }
        return layer
    }
}
