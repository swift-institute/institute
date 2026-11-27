internal import Institute_Model
internal import Package_Manager

extension Institute.Inventory {
    /// Turns what was read into the tables, resolving references on the way.
    struct Assembly {
        let root: Swift.String
        let repositories: [Repository]
        let members: [Member]
        let targets: [Target]
        /// `(target index, file relative to the target directory, facts)`.
        let files: [(Swift.Int, Swift.String, Facts?)]
        let failures: [(path: Swift.String, reason: Swift.String)]
    }
}

extension Institute.Inventory.Assembly {
    func tables() -> ([Institute.Inventory.Table], Institute.Inventory.Summary) {
        var summary = Institute.Inventory.Summary()
        summary.repositories = repositories.count
        summary.packages = members.count
        summary.targets = targets.count
        summary.files = files.count
        summary.failures = failures.count

        let targetIndex = Self.targetIndex(members: members, targets: targets)
        let dependencyPackages = self.dependencyPackages()
        let graph = Graph(
            members: members,
            targets: targets,
            targetIndex: targetIndex,
            dependencyPackages: dependencyPackages
        )

        var tables: [Institute.Inventory.Table] = []
        tables.append(repositoriesTable())
        tables.append(packagesTable())
        tables.append(packageDependenciesTable())
        tables.append(traitsTable())
        tables.append(productsTable())
        tables.append(targetsTable())
        tables.append(targetDependenciesTable(graph: graph))
        tables.append(importsTable())
        let (types, declarations) = typesTable()
        summary.types = types.rows.count
        tables.append(types)
        tables.append(extensionsTable())

        var references: [Institute.Inventory.Reference.Key: Swift.Int] = [:]
        for (target, _, facts) in files {
            guard let facts else { continue }
            for reference in facts.references {
                references[
                    .init(
                        target: target,
                        from: reference.from,
                        module: reference.module,
                        chain: reference.chain,
                        position: reference.position,
                        generic: reference.generic
                    ),
                    default: 0
                ] += 1
            }
        }
        summary.references = references.values.reduce(0, +)
        let ordered = references.sorted { $0.key < $1.key }
        tables.append(
            Institute.Inventory.Table(
                name: "references",
                rows: ordered.map { key, count in
                    location(key.target) + [
                        ("from", .text(key.from.joined(separator: "."))),
                        ("written", .text(key.written)),
                        ("position", .text(key.position.spelling)),
                        ("generic_parameter", .flag(key.generic)),
                        ("count", .number(count)),
                    ]
                }
            )
        )

        var modules: Swift.Set<Swift.String> = ["Swift", "_Concurrency", "Foundation", "Darwin", "Glibc", "Dispatch"]
        for target in targets { modules.insert(Self.moduleName(target.name)) }
        for (_, _, facts) in files { for module in facts?.imports ?? [] { modules.insert(module.module) } }
        let resolver = Institute.Inventory.Resolver(declarations: declarations, modules: modules)
        var genericParameters: [Swift.String: Swift.Set<Swift.String>] = [:]
        for (_, _, facts) in files {
            for type in facts?.types ?? [] where !(type.generics + type.associated).isEmpty {
                genericParameters[type.path.joined(separator: "."), default: []]
                    .formUnion(type.generics + type.associated)
            }
        }

        var resolved: [Institute.Inventory.Reference.Resolved: Swift.Int] = [:]
        var unresolved: [Institute.Inventory.Reference.Unresolved: Swift.Int] = [:]
        var visibility: [Swift.Int: Swift.Set<Swift.Int>] = [:]
        for (key, count) in ordered {
            let visible: Swift.Set<Swift.Int>
            if let known = visibility[key.target] {
                visible = known
            } else {
                visible = graph.visible(from: key.target)
                visibility[key.target] = visible
            }
            // WHY: inside an extension the extended type's generic parameters
            // are in scope too, though the extension does not declare them.
            var generic = key.generic
            if !generic, key.module.isEmpty, let first = key.chain.first, !key.from.isEmpty {
                generic = (1...key.from.count).contains { length in
                    genericParameters[key.from.prefix(length).joined(separator: ".")]?.contains(first) ?? false
                }
            }
            let resolution = resolver.resolve(
                chain: key.chain,
                module: key.module,
                from: key.from,
                generic: generic,
                visible: visible
            )
            if resolution.candidates.isEmpty {
                unresolved[.init(target: key.target, written: key.written), default: 0] += count
                continue
            }
            for candidate in resolution.candidates {
                resolved[
                    .init(
                        target: key.target,
                        from: key.from.joined(separator: "."),
                        position: key.position,
                        path: candidate.path,
                        declaring: candidate.target,
                        ambiguous: resolution.ambiguous
                    ),
                    default: 0
                ] += count
            }
        }
        let resolvedRows = resolved.sorted { $0.key < $1.key }.map { key, count -> Institute.Inventory.Table.Row in
            let declaring = targets[key.declaring]
            return location(key.target) + [
                ("from", .text(key.from)),
                ("position", .text(key.position.spelling)),
                ("type_path", .text(key.path)),
                ("type_target", .text(declaring.name)),
                ("type_package", .text(members[declaring.package].path)),
                ("ambiguous", .flag(key.ambiguous)),
                ("count", .number(count)),
            ]
        }
        summary.resolved = resolvedRows.count
        summary.ambiguous = resolved.keys.filter(\.ambiguous).count
        tables.append(Institute.Inventory.Table(name: "resolved_references", rows: resolvedRows))
        let unresolvedRows = unresolved.sorted { $0.key < $1.key }.map { key, count -> Institute.Inventory.Table.Row in
            location(key.target) + [("written", .text(key.written)), ("count", .number(count))]
        }
        summary.unresolved = unresolvedRows.count
        tables.append(Institute.Inventory.Table(name: "unresolved_references", rows: unresolvedRows))

        tables.append(
            Institute.Inventory.Table(
                name: "failures",
                rows: failures.map { [("package", .text($0.path)), ("reason", .text($0.reason))] }
            )
        )
        return (tables, summary)
    }

    func location(_ target: Swift.Int) -> Institute.Inventory.Table.Row {
        [("package", .text(members[targets[target].package].path)), ("target", .text(targets[target].name))]
    }
}

extension Institute.Inventory.Assembly {
    func repositoriesTable() -> Institute.Inventory.Table {
        .init(
            name: "repositories",
            rows: repositories.map { repository in
                let owner = repository.origin.split(separator: "/").first.map(Swift.String.init) ?? ""
                let layer = Institute.Organization(rawValue: owner).map { "\($0.layer)" } ?? ""
                return [
                    ("path", .text(repository.path)),
                    ("origin", .text(repository.origin)),
                    ("organization", .text(owner)),
                    ("layer", .text(layer)),
                    ("head", .text(repository.head)),
                    ("dirty", .flag(repository.dirty)),
                ]
            }
        )
    }

    func packagesTable() -> Institute.Inventory.Table {
        .init(
            name: "packages",
            rows: members.map { member in
                [
                    ("package", .text(member.path)),
                    ("repository", .text(member.repository)),
                    ("name", .text(member.evaluation.name.underlying)),
                    ("nested", .flag(member.path != member.repository)),
                    ("tools_version", .text("\(member.evaluation.toolsVersion)")),
                    ("targets", .number(member.targets.count)),
                    ("products", .number(member.evaluation.products.count)),
                ]
            }
        )
    }

    func packageDependenciesTable() -> Institute.Inventory.Table {
        var rows: [Institute.Inventory.Table.Row] = []
        for member in members {
            for dependency in member.evaluation.dependencies {
                rows.append([
                    ("package", .text(member.path)),
                    ("identity", .text(dependency.identity.underlying)),
                    ("kind", .text(Self.kind(dependency.source))),
                    ("location", .text(Self.location(dependency.source))),
                    ("requirement", .text(Self.requirement(dependency.requirement))),
                    ("traits", .text(dependency.traits.map(\.name).joined(separator: ","))),
                ])
            }
        }
        return .init(name: "package_dependencies", rows: rows)
    }

    func traitsTable() -> Institute.Inventory.Table {
        var rows: [Institute.Inventory.Table.Row] = []
        for member in members {
            for trait in member.evaluation.traits {
                rows.append([
                    ("package", .text(member.path)),
                    ("name", .text(trait.name)),
                    ("enables", .text(trait.enabledTraits.joined(separator: ","))),
                ])
            }
        }
        return .init(name: "traits", rows: rows)
    }

    func productsTable() -> Institute.Inventory.Table {
        var rows: [Institute.Inventory.Table.Row] = []
        for member in members {
            for product in member.evaluation.products {
                let kind: Swift.String
                let library: Swift.String
                switch product.kind {
                case .library(let type):
                    kind = "library"
                    library =
                        switch type {
                        case .static: "static"
                        case .dynamic: "dynamic"
                        case .automatic: "automatic"
                        }
                case .executable:
                    kind = "executable"
                    library = ""
                case .plugin:
                    kind = "plugin"
                    library = ""
                }
                rows.append([
                    ("package", .text(member.path)),
                    ("name", .text(product.name.underlying)),
                    ("kind", .text(kind)),
                    ("library_type", .text(library)),
                    ("targets", .text(product.targets.map(\.underlying).joined(separator: ","))),
                ])
            }
        }
        return .init(name: "products", rows: rows)
    }

    func targetsTable() -> Institute.Inventory.Table {
        var counts = [(files: Swift.Int, lines: Swift.Int)](repeating: (0, 0), count: targets.count)
        for (target, _, facts) in files {
            counts[target].files += 1
            counts[target].lines += facts?.lines ?? 0
        }
        return .init(
            name: "targets",
            rows: targets.enumerated().map { offset, target in
                let kind =
                    switch target.manifest.kind {
                    case .regular: "regular"
                    case .executable: "executable"
                    case .test: "test"
                    case .plugin: "plugin"
                    case .binary: "binary"
                    case .system: "system"
                    case .macro: "macro"
                    }
                return location(offset) + [
                    ("kind", .text(kind)),
                    ("path", .text(target.path)),
                    ("files", .number(counts[offset].files)),
                    ("lines", .number(counts[offset].lines)),
                ]
            }
        )
    }

    func targetDependenciesTable(graph: Graph) -> Institute.Inventory.Table {
        var rows: [Institute.Inventory.Table.Row] = []
        for (offset, target) in targets.enumerated() {
            for dependency in target.manifest.dependencies {
                let condition = target.manifest.conditions[dependency]
                let kind: Swift.String
                let name: Swift.String
                let package: Swift.String
                switch dependency {
                case .target(let named):
                    kind = "target"
                    name = named.underlying
                    package = ""
                case .product(let named, let from):
                    kind = "product"
                    name = named.underlying
                    package = from.underlying
                case .byName(let named):
                    kind = graph.sameTarget(named, package: target.package) == nil ? "product" : "target"
                    name = named
                    package = ""
                }
                rows.append(
                    location(offset) + [
                        ("kind", .text(kind)),
                        ("name", .text(name)),
                        ("dependency_package", .text(package)),
                        ("platforms", .text(condition?.platforms.joined(separator: ",") ?? "")),
                        ("traits", .text(condition?.traits.map { $0.sorted().joined(separator: ",") } ?? "")),
                    ]
                )
            }
        }
        return .init(name: "target_dependencies", rows: rows)
    }
}

extension Institute.Inventory.Assembly {
    func importsTable() -> Institute.Inventory.Table {
        struct Key: Hashable, Comparable {
            var target: Swift.Int
            var module: Swift.String
            var access: Swift.String
            var exported: Swift.Bool
            var attributes: Swift.String
            var condition: Swift.String
            static func < (lhs: Key, rhs: Key) -> Swift.Bool {
                (lhs.target, lhs.module, lhs.access, lhs.attributes, lhs.condition)
                    < (rhs.target, rhs.module, rhs.access, rhs.attributes, rhs.condition)
            }
        }
        var counts: [Key: Swift.Int] = [:]
        for (target, _, facts) in files {
            guard let facts else { continue }
            let keys = Swift.Set(
                facts.imports.map {
                    Key(
                        target: target,
                        module: $0.module,
                        access: $0.access,
                        exported: $0.exported,
                        attributes: $0.attributes,
                        condition: $0.condition
                    )
                }
            )
            for key in keys { counts[key, default: 0] += 1 }
        }
        return .init(
            name: "imports",
            rows: counts.sorted { $0.key < $1.key }.map { key, count in
                location(key.target) + [
                    ("module", .text(key.module)),
                    ("access", .text(key.access)),
                    ("exported", .flag(key.exported)),
                    ("attributes", .text(key.attributes)),
                    ("condition", .text(key.condition)),
                    ("files", .number(count)),
                ]
            }
        )
    }

    func file(_ target: Swift.Int, _ file: Swift.String) -> Swift.String {
        let directory = targets[target].path
        return directory == "." ? file : directory + "/" + file
    }

    func typesTable() -> (Institute.Inventory.Table, [(path: [Swift.String], target: Swift.Int)]) {
        var rows: [Institute.Inventory.Table.Row] = []
        var declarations: [(path: [Swift.String], target: Swift.Int)] = []
        let sorted = files.enumerated().sorted { lhs, rhs in
            let (left, right) = (lhs.element, rhs.element)
            return (members[targets[left.0].package].path, targets[left.0].name, left.1)
                < (members[targets[right.0].package].path, targets[right.0].name, right.1)
        }
        for (_, (target, name, facts)) in sorted {
            guard let facts else { continue }
            for type in facts.types {
                declarations.append((type.path, target))
                rows.append(
                    [("id", .number(rows.count + 1))] + location(target) + [
                        ("path", .text(type.path.joined(separator: "."))),
                        ("name", .text(type.name)),
                        ("kind", .text(type.kind)),
                        ("access", .text(type.access)),
                        ("generic_parameters", .text(type.generics.joined(separator: ","))),
                        ("associated_types", .text(type.associated.joined(separator: ","))),
                        ("cases", .number(type.cases)),
                        ("stored_properties", .number(type.stored)),
                        ("inherits", .text(type.inherits.joined(separator: ","))),
                        ("aliased", .text(type.aliased)),
                        ("in_extension", .flag(type.isInExtension)),
                        ("module_selector", .text(type.module)),
                        ("condition", .text(type.condition)),
                        ("file", .text(file(target, name))),
                        ("line", .number(type.line)),
                    ]
                )
            }
        }
        return (.init(name: "types", rows: rows), declarations)
    }

    func extensionsTable() -> Institute.Inventory.Table {
        var rows: [Institute.Inventory.Table.Row] = []
        for (target, name, facts) in files {
            guard let facts else { continue }
            for declaration in facts.extensions {
                rows.append(
                    location(target) + [
                        ("extended", .text(declaration.extended.joined(separator: "."))),
                        ("module_selector", .text(declaration.module)),
                        ("conformances", .text(declaration.conformances.joined(separator: ","))),
                        ("where_clause", .text(declaration.requirements)),
                        ("public_members", .number(declaration.surface)),
                        ("nested_types", .number(declaration.nested)),
                        ("condition", .text(declaration.condition)),
                        ("file", .text(file(target, name))),
                        ("line", .number(declaration.line)),
                    ]
                )
            }
        }
        return .init(name: "extensions", rows: rows)
    }
}

extension Institute.Inventory.Assembly {
    static func targetIndex(
        members: [Institute.Inventory.Member],
        targets: [Institute.Inventory.Target]
    ) -> [[Swift.String: Swift.Int]] {
        var index = [[Swift.String: Swift.Int]](repeating: [:], count: members.count)
        for (offset, target) in targets.enumerated() where index[target.package][target.name] == nil {
            index[target.package][target.name] = offset
        }
        return index
    }

    /// For each package, the package under the root each declared
    /// dependency names, keyed by lowercased identity.
    func dependencyPackages() -> [[Swift.String: Swift.Int]] {
        var byPath: [Swift.String: Swift.Int] = [:]
        for (offset, member) in members.enumerated() { byPath[member.path] = offset }
        var byOrigin: [Swift.String: [Swift.String]] = [:]
        for repository in repositories where !repository.origin.isEmpty {
            byOrigin[repository.origin.lowercased(), default: []].append(repository.path)
        }
        func canonical(_ slug: Swift.String) -> Swift.Int? {
            let lowered = slug.lowercased()
            let candidates = (byOrigin[lowered] ?? []).filter { byPath[$0] != nil }
            let preferred =
                candidates.first { $0.lowercased() == lowered || $0.lowercased().hasSuffix("/" + lowered) }
                ?? candidates.min { ($0.count, $0) < ($1.count, $1) }
            return preferred.flatMap { byPath[$0] }
        }
        return members.map { member in
            var result: [Swift.String: Swift.Int] = [:]
            let directory = Institute.Inventory.absolute(member.path, root: root)
            for dependency in member.evaluation.dependencies {
                let found: Swift.Int?
                switch dependency.source {
                case .fileSystem(_, let path):
                    found = Self.relative(Self.normalize(path, in: directory), root: root).flatMap { byPath[$0] }
                case .sourceControl(_, .local(let path), _):
                    found = Self.relative(Self.normalize(path, in: directory), root: root).flatMap { byPath[$0] }
                case .sourceControl(_, .remote(let uri), _):
                    found = Institute.Inventory.slug("\(uri)").flatMap(canonical)
                case .registry:
                    found = nil
                }
                if let found { result[dependency.identity.underlying.lowercased()] = found }
            }
            return result
        }
    }

    static func normalize(_ path: Swift.String, in directory: Swift.String) -> Swift.String {
        let joined = path.hasPrefix("/") ? path : directory + "/" + path
        var components: [Swift.Substring] = []
        for component in joined.split(separator: "/") {
            switch component {
            case ".": continue
            case "..": if !components.isEmpty { components.removeLast() }
            default: components.append(component)
            }
        }
        return "/" + components.joined(separator: "/")
    }

    static func relative(_ path: Swift.String, root: Swift.String) -> Swift.String? {
        if path == root { return "." }
        guard path.hasPrefix(root + "/") else { return nil }
        return Swift.String(path.dropFirst(root.count + 1))
    }

    /// The name a target is imported by: every character that is not a
    /// letter, digit or underscore becomes an underscore.
    static func moduleName(_ target: Swift.String) -> Swift.String {
        var name = Swift.String(
            target.map { $0.isLetter || $0.isNumber || $0 == "_" ? $0 : "_" }
        )
        if name.first?.isNumber == true { name = "_" + name }
        return name
    }

    static func kind(_ source: Package.Dependency.Evaluation.Source) -> Swift.String {
        switch source {
        case .fileSystem: "path"
        case .sourceControl(_, .local, _): "local"
        case .sourceControl: "url"
        case .registry: "registry"
        }
    }

    static func location(_ source: Package.Dependency.Evaluation.Source) -> Swift.String {
        switch source {
        case .fileSystem(_, let path): path
        case .sourceControl(_, .local(let path), _): path
        case .sourceControl(_, .remote(let uri), _): "\(uri)"
        case .registry(let identity, _): "\(identity)"
        }
    }

    static func requirement(_ requirement: Package.Requirement?) -> Swift.String {
        guard let requirement else { return "" }
        switch requirement {
        case .from(let version): return "from \(version)"
        case .upToNextMajor(let version): return "upToNextMajor \(version)"
        case .upToNextMinor(let version): return "upToNextMinor \(version)"
        case .range(let range): return "range \(range)"
        case .exact(let version): return "exact \(version)"
        case .branch(let branch): return "branch \(branch)"
        case .revision(let revision): return "revision \(revision)"
        }
    }
}
