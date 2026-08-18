public import Async_Fanout
public import File_System
public import Institute_Development
public import Institute_Inventory
public import Institute_Lint
public import Institute_Model
public import Institute_Pages
public import Package_Manager

extension Institute.Doctor {
    /// One name in one composed-graph namespace, with every repository
    /// that declares it.
    ///
    /// The composed-root build path (``Institute/Composed``, issue #81)
    /// merges every selected repository into one SwiftPM graph, where
    /// target names are module names and library product names are the
    /// addressable dependency surface. Both namespaces are therefore
    /// fleet-wide: a name declared by two repositories breaks every
    /// composed slice that includes both owners.
    ///
    /// Ownership is per repository, never per declaration: a manifest
    /// that declares the same name more than once (for example, the same
    /// target under different platform conditions) still owns the name
    /// exactly once, so a within-manifest duplicate can never fire this
    /// check.
    public struct Uniqueness: Equatable, Sendable {
        public let namespace: Namespace
        public let name: Swift.String
        /// The names of every repository declaring the name, sorted.
        public let owners: [Swift.String]

        public init(namespace: Namespace, name: Swift.String, owners: [Swift.String]) {
            self.namespace = namespace
            self.name = name
            self.owners = owners
        }
    }
}

extension Institute.Doctor {
    /// Every library product name and every buildable target name is
    /// owned by exactly one repository.
    public static let uniqueness = Check<Uniqueness>(
        name: "name-uniqueness",
        scope: .contributor,
        controls: .init(
            positive: .init(namespace: .target, name: "control", owners: ["a", "b"]),
            negative: .init(namespace: .target, name: "control", owners: ["a"])
        )
    ) { subject in
        subject.owners.count > 1
            ? [
                .init(
                    severity: .error,
                    message:
                        "\(subject.namespace) \(subject.name) is declared by "
                        + subject.owners.joined(separator: ", ")
                )
            ]
            : []
    }

    /// One manifest evaluation per materialized repository, gathered
    /// concurrently, then aggregated into one fleet-wide population of
    /// names.
    ///
    /// Uniqueness is a property of the whole fleet, so partial coverage
    /// can never masquerade as a proven-unique fleet: a selected
    /// repository that is not materialized, or a manifest that fails to
    /// evaluate, degrades the whole check to `unmeasured` rather than
    /// shrinking the population it silently passes over.
    func uniqueness(_ materialized: [(Institute.Repository, File.Directory)]) async -> Outcome {
        guard materialized.count == selection.repositories.count else {
            return Self.uniqueness.unmeasured(
                reason:
                    "\(materialized.count) of \(selection.repositories.count) selected "
                    + "repositories are materialized; uniqueness is fleet-wide and cannot "
                    + "be proven from a partial fleet"
            )
        }
        let readings = await fanout.map(
            materialized,
            completed: progress.steps(
                "name-uniqueness: evaluated",
                of: materialized.count
            )
        ) { entry in
            let (repository, path) = entry
            return self.reading(of: repository, at: path)
        }
        var declarations = [Uniqueness.Declaration]()
        for reading in readings {
            switch reading {
            case .declared(let declaration):
                declarations.append(declaration)

            case .absent:
                continue

            case .unevaluable(let repository, let diagnostic):
                return Self.uniqueness.unmeasured(
                    reason: "cannot evaluate the manifest of \(repository): \(diagnostic)"
                )
            }
        }
        return Self.uniqueness.run(
            population: Uniqueness.population(of: declarations),
            inventory: selection.repositories.count
        )
    }

    /// One repository's contribution: its library product names and its
    /// buildable target names, read from the same `dump-package`
    /// evaluation the composed-root generator reads
    /// (``Institute/Composed/manifests(for:at:packages:)``), with the
    /// same kind filters — library products are the only products another
    /// target can depend on, and regular and executable targets are the
    /// modules a composed slice compiles.
    private func reading(
        of repository: Institute.Repository,
        at path: File.Directory
    ) -> Uniqueness.Reading {
        guard path[file: "Package.swift"].stat.exists else { return .absent }
        let evaluation: Package.Manifest.Evaluation
        do throws(Package.Manager.Error) {
            evaluation = try packages.evaluation(at: path.description)
        } catch {
            return .unevaluable(repository: repository.name, diagnostic: "\(error)")
        }
        let products: [Swift.String] = evaluation.products.compactMap { product in
            guard case .library = product.kind else { return nil }
            return product.name.underlying
        }
        let targets: [Swift.String] = evaluation.targets.compactMap { target in
            switch target.kind {
            case .regular, .executable: target.name.underlying
            case .test, .plugin, .binary, .system, .macro: nil
            }
        }
        return .declared(
            .init(repository: repository.name, products: products, targets: targets)
        )
    }
}

extension Institute.Doctor.Uniqueness {
    /// Aggregates per-repository declarations into the check's
    /// population: one subject per distinct name per namespace, owned by
    /// the sorted set of repositories declaring it.
    ///
    /// Ownership collapses per repository here — declaring a name twice
    /// in one manifest and declaring it once are the same fact — which is
    /// what confines the check to *cross-repository* collisions.
    public static func population(of declarations: [Declaration]) -> [Self] {
        var products = [Swift.String: Swift.Set<Swift.String>]()
        var targets = [Swift.String: Swift.Set<Swift.String>]()
        for declaration in declarations {
            for product in declaration.products {
                products[product, default: []].insert(declaration.repository)
            }
            for target in declaration.targets {
                targets[target, default: []].insert(declaration.repository)
            }
        }
        let productSubjects = products
            .map { Self(namespace: .product, name: $0.key, owners: $0.value.sorted()) }
            .sorted { $0.name < $1.name }
        let targetSubjects = targets
            .map { Self(namespace: .target, name: $0.key, owners: $0.value.sorted()) }
            .sorted { $0.name < $1.name }
        return productSubjects + targetSubjects
    }
}
