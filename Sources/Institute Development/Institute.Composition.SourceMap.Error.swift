public import Institute_Model

extension Institute.Composition.SourceMap {
    public enum Error: Swift.Error, Swift.Sendable {
        /// A seed reference names no inventory repository.
        case unknownSeed(Swift.String)

        /// An explicit seed selection contained no seeds.
        case emptySeeds

        /// An override references a repository outside the inventory.
        case unknownOverride(Swift.String)

        /// An override references a repository outside the normalized
        /// scope.
        case outOfScopeOverride(Swift.String)

        /// A hierarchy the map references is not registered, or its
        /// root fails validation.
        case hierarchy(Swift.String, Institute.Error)

        /// A repository's resolved directory fails layout or
        /// containment validation against its own hierarchy root.
        case placement(Swift.String, Institute.Error)

        /// A repository's resolved directory carries no `Package.swift`.
        case missingManifest(Swift.String)

        /// A repository's manifest failed to evaluate. Never a silent
        /// omission: skipping would understate the closure while still
        /// reporting one.
        case evaluation(Swift.String, Swift.String)

        /// Two scope repositories resolve to one physical directory.
        case duplicatePath(Swift.String, Swift.String)

        /// One evaluated identity appears at two paths.
        case duplicateIdentity(identity: Swift.String, first: Swift.String, second: Swift.String)

        /// The evaluated identity of a repository diverges from its
        /// inventory reference. Reported with both, never silently
        /// accepted — identity is only ever taken from evaluation.
        case identityDivergence(reference: Swift.String, evaluated: Swift.String)

        /// A closure repository has no source assignment.
        case unassigned(Swift.String)

        /// A dependency under an Institute-governed organization is
        /// absent from the declared population. Presumptively an
        /// inventory-integrity failure, never a lawful external — a
        /// governed edge outside the census would silently leave the
        /// composed local graph and resolve remotely (the swift-tls
        /// class, institute-application#212).
        case populationIntegrity(
            reference: Swift.String,
            identity: Swift.String,
            organization: Swift.String
        )
    }
}

extension Institute.Composition.SourceMap.Error: Swift.CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .unknownSeed(let seed):
            "seed \(seed) names no inventory repository"

        case .emptySeeds:
            "an explicit seed selection must name at least one repository"

        case .unknownOverride(let reference):
            "override \(reference) names no inventory repository"

        case .outOfScopeOverride(let reference):
            "override \(reference) is outside the normalized scope"

        case .hierarchy(let id, let error):
            "hierarchy \(id) cannot be resolved: \(error)"

        case .placement(let reference, let error):
            "\(reference) fails placement validation: \(error)"

        case .missingManifest(let reference):
            "\(reference)'s checkout carries no Package.swift"

        case .evaluation(let reference, let message):
            "cannot evaluate the manifest of \(reference): \(message)"

        case .duplicatePath(let first, let second):
            "\(first) and \(second) resolve to one physical directory"

        case .duplicateIdentity(let identity, let first, let second):
            "evaluated identity \(identity) appears at two paths: \(first), \(second)"

        case .identityDivergence(let reference, let evaluated):
            "inventory reference \(reference) evaluates to divergent identity \(evaluated)"

        case .unassigned(let reference):
            "closure repository \(reference) has no source assignment"

        case .populationIntegrity(let reference, let identity, let organization):
            "\(reference) depends on \(identity) under governed organization "
                + "\(organization), which is absent from the declared population"
        }
    }
}
