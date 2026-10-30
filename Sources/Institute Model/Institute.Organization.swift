extension Institute {
    public enum Organization: Swift.String, Swift.CaseIterable, Swift.Sendable {
        case `swift-institute`
        case `swift-atoms`
        case `swift-molecules`
        case `swift-standards`
        case `swift-arm-ltd`
        case `swift-bipm`
        case `swift-ecma`
        case `swift-iec`
        case `swift-ieee`
        case `swift-ietf`
        case `swift-incits`
        case `swift-intel`
        case `swift-iso`
        case `swift-linux-foundation`
        case `swift-microsoft`
        case `swift-riscv`
        case `swift-w3c`
        case `swift-whatwg`
        case `swift-compositions`
    }
}

extension Institute.Organization {
    public var layer: Layer {
        switch self {
        case .`swift-institute`: .control
        case .`swift-atoms`: .atoms
        case .`swift-molecules`: .molecules
        case .`swift-standards`, .`swift-arm-ltd`, .`swift-bipm`, .`swift-ecma`, .`swift-iec`,
            .`swift-ieee`, .`swift-ietf`, .`swift-incits`, .`swift-intel`, .`swift-iso`,
            .`swift-linux-foundation`, .`swift-microsoft`, .`swift-riscv`, .`swift-w3c`,
            .`swift-whatwg`:
            .standards
        case .`swift-compositions`: .compositions
        }
    }

    public init?(url: Swift.String) {
        let prefix = "https://github.com/"
        guard url.hasPrefix(prefix) else { return nil }
        guard let owner = url.dropFirst(prefix.count).split(separator: "/").first else { return nil }
        self.init(rawValue: Swift.String(owner))
    }
}

extension Institute.Organization {
    public var lintBundle: Swift.String {
        switch layer {
        case .atoms, .molecules: "primitives"
        case .standards: "standards"
        case .compositions, .control: "institute"
        }
    }
}

extension Institute.Organization {
    public static func lintBundle(forRepository repository: Swift.String) -> Swift.String {
        Institute.Repository.Coordinate(repository)?.organization.lintBundle ?? "institute"
    }
}

extension Institute.Organization {
    public var implementsExternalSpecification: Swift.Bool? {
        switch layer {
        case .standards: true
        case .atoms, .molecules, .compositions, .control: nil
        }
    }
}
