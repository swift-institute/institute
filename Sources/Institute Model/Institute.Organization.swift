public import GitHub_Standard

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

    /// The organization of the repository on github.com that a git remote names, as a manifest's dependency spells
    /// it, or `nil` when it names none or one outside the Institute. `GitHub.Repository.Slug.init(remote:)` reads it.
    public init?(remote: Swift.String) {
        guard let repository = GitHub_Standard::GitHub.Repository.Slug(remote: remote),
            let coordinate = Institute.Repository.Coordinate(repository)
        else { return nil }
        self = coordinate.organization
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
    /// The bundle `repository` lints under: a repository outside the Institute's organizations, or none named, is `institute`.
    public static func lintBundle(forRepository repository: GitHub_Standard::GitHub.Repository.Slug?) -> Swift.String {
        repository.flatMap { Institute.Repository.Coordinate($0) }?.organization.lintBundle ?? "institute"
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
