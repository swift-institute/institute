public import Institute_Model
public import Institute_CI_Model

extension Institute.CI.Canon.Gitignore {
    /// The repository class a canonical `.gitignore` is written for.
    ///
    /// One canon cannot describe the whole fleet: a scaffold has no
    /// `Sources/` to admit, the control plane tracks `canon/` and
    /// `Tools/` no package may, and an application ships configuration
    /// a library never carries. Each class owns one canon document —
    /// `canon/gitignore-<class>.txt` — and every document is the same
    /// deny-by-default shape: `/*` denies every top-level entry, `!/…`
    /// re-includes the admitted ones, `**/.*/` denies tool-state
    /// dot-directories at every depth. Classes differ only in *what is
    /// admitted*, never in shape.
    ///
    /// Repository-specific handwritten admissions are not supported. The
    /// generated class document is the complete policy.
    public enum Class: String, CaseIterable, Sendable, Equatable {
        /// An ordinary package: a layer-org repository with a root
        /// `Package.swift`. The original canon, unchanged.
        case package

        /// A repository with no root `Package.swift`: a reserved name
        /// holding its uniform CI caller, README, and licence until a
        /// package arrives. Minimal by definition — a scaffold that
        /// needs `Sources/` needs a manifest first.
        case scaffold

        /// A `swift-institute` control-plane repository. Admits the
        /// package shape plus the control plane's own artifacts —
        /// distributed canon, policy, tools, org profile — and root
        /// documents, which are the control plane's work product.
        case institute

        /// An application package: the package shape plus deployment
        /// surface (`Public/`, `Resources/`, `Configuration/`, an
        /// `.env.example` template). Membership is assigned, never
        /// inferred: no manifest fact separates an application from a
        /// library with an executable.
        case application

        /// A generator-based standards package — the typed exception
        /// class: the package shape plus `!/Generation/` for the
        /// generator that produces its sources. Detected from the
        /// manifest where possible, else assigned.
        case generator
    }
}

extension Institute.CI.Canon.Gitignore.Class {
    /// Canon's path for this class within the control-plane checkout.
    public var canonPath: String { "canon/gitignore-\(rawValue).txt" }

    /// The central typed exception list: repositories whose class is
    /// assigned rather than derived, keyed by full `owner/name`.
    ///
    /// Only `application` and `generator` need assignment — `package`,
    /// `scaffold`, and `institute` are derived from checkout facts.
    /// Empty today: no repository is yet ruled into either class, and
    /// an unruled member would flip a conformant repository divergent.
    /// Admission to this list rides the convergence ruling, not this
    /// file's history.
    public static let assignments: [String: Self] = [:]

    /// The class of a repository, decided from its full `owner/name`
    /// and the text of its root manifest (`nil` when it has none).
    ///
    /// Order matters and is the authority order: an explicit assignment
    /// outranks derivation, the control-plane org outranks manifest
    /// facts, and the manifest's generator fact outranks the ordinary
    /// default.
    public static func of(repository: String, manifest: String?) -> Self {
        if let assigned = assignments[repository] { return assigned }
        if repository.hasPrefix("swift-institute/") { return .institute }
        guard let manifest else { return .scaffold }
        if manifest.contains("Generation\"") || manifest.contains("Generator\"") {
            // A target or product named for generation is the one
            // mechanical generator fact a manifest carries today.
            return .generator
        }
        return .package
    }
}
