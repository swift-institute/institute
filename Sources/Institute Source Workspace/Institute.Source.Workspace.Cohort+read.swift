extension Institute.Source.Workspace.Cohort {
    public static func read(
        from workspace: Swift.String,
        configuration: Institute.Configuration,
        hierarchy: File.Directory
    ) throws(Institute.Error) -> Self {
        let document: Xcode.Workspace
        do throws(Xcode.Workspace.Error) { document = try .read(from: workspace) }
        catch { throw .configuration("cannot read source workspace \(workspace): \(error)") }

        let bundle: File.Path
        do throws(File.Path.Error) { bundle = try .init(workspace) }
        catch { throw .configuration("invalid source workspace path \(workspace)") }
        guard let container = File.Directory(bundle).parent else {
            throw .configuration("source workspace has no containing directory")
        }

        var expected: [Swift.String: Institute.Repository] = [:]
        for repository in configuration.repositories {
            let directory = try Institute.Layout.directory(for: repository, at: hierarchy)
            let canonical: File.Path
            do throws(File.System.Canonical.Error) {
                canonical = try File.System.Canonical.resolve(directory.path)
            } catch { continue }
            guard expected[canonical.description] == nil else {
                throw .configuration("duplicate inventory materialization at \(canonical)")
            }
            expected[canonical.description] = repository
        }

        var flattened: [(Xcode.Workspace.Location, File.Directory)] = []
        var reasons: [SourceDomain.Reason] = []
        for reference in document.references {
            Self.flatten(
                reference,
                group: container,
                container: container,
                into: &flattened,
                reasons: &reasons
            )
        }

        var rows: [Institute.Source.Workspace.Row] = []
        var canonicalPaths: Swift.Set<Swift.String> = []
        var groupCount = 0
        var containerCount = 0
        for (index, entry) in flattened.enumerated() {
            switch entry.0.scheme {
            case .group: groupCount += 1
            case .container: containerCount += 1
            case .absolute, .self, .other: break
            }
            let canonical: File.Path
            do throws(File.System.Canonical.Error) {
                canonical = try File.System.Canonical.resolve(entry.1.path)
            } catch {
                let reason = SourceDomain.Reason(
                    code: "unresolved-reference",
                    detail: entry.0.rawValue
                )
                reasons.append(reason)
                rows.append(
                    .init(
                        index: index,
                        location: entry.0,
                        directory: entry.1.description,
                        identity: Self.attemptedIdentity(entry.1.path, hierarchy: hierarchy),
                        repository: nil,
                        reason: reason
                    )
                )
                continue
            }
            let identity = Self.attemptedIdentity(canonical, hierarchy: hierarchy)
            let duplicate = !canonicalPaths.insert(canonical.description).inserted
            let manifest = File.Directory(canonical)[file: "Package.swift"].stat.isFile
            let repository = expected[canonical.description]
            let reason: SourceDomain.Reason?
            if duplicate {
                reason = .init(code: "duplicate-reference", detail: canonical.description)
            } else if !manifest {
                reason = .init(code: "missing-manifest", detail: canonical.description)
            } else if repository == nil {
                reason = .init(code: "inventory-identity", detail: identity)
            } else {
                reason = nil
            }
            if let reason { reasons.append(reason) }
            rows.append(
                .init(
                    index: index,
                    location: entry.0,
                    directory: canonical.description,
                    identity: identity,
                    repository: repository,
                    reason: reason
                )
            )
        }
        guard !rows.isEmpty else {
            reasons.append(.init(code: "empty-workspace", detail: workspace))
        }
        return .init(
            workspace: workspace,
            references: rows.count,
            groupReferences: groupCount,
            containerReferences: containerCount,
            rows: rows,
            reasons: reasons
        )
    }

    private static func flatten(
        _ reference: Xcode.Workspace.Reference,
        group: File.Directory,
        container: File.Directory,
        into entries: inout [(Xcode.Workspace.Location, File.Directory)],
        reasons: inout [SourceDomain.Reason]
    ) {
        switch reference {
        case .file(let location):
            guard let directory = Self.resolve(location, group: group, container: container) else {
                reasons.append(.init(code: "location-scheme", detail: location.rawValue))
                return
            }
            entries.append((location, directory))
        case .group(let nested):
            guard let base = Self.resolve(nested.location, group: group, container: container) else {
                reasons.append(.init(code: "location-scheme", detail: nested.location.rawValue))
                return
            }
            for child in nested.references {
                Self.flatten(child, group: base, container: container, into: &entries, reasons: &reasons)
            }
        }
    }

    private static func resolve(
        _ location: Xcode.Workspace.Location,
        group: File.Directory,
        container: File.Directory
    ) -> File.Directory? {
        let base: File.Directory
        switch location.scheme {
        case .group, .self: base = group
        case .container: base = container
        case .absolute:
            guard let path = try? File.Path(location.path) else { return nil }
            return File.Directory(path)
        case .other: return nil
        }
        guard let relative = try? File.Path(location.path) else { return nil }
        return File.Directory(base.path / relative)
    }

    private static func attemptedIdentity(
        _ path: File.Path,
        hierarchy: File.Directory
    ) -> Swift.String {
        let root = hierarchy.path.description
        let value = path.description
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard value.hasPrefix(prefix) else { return value }
        let components = value.dropFirst(prefix.count).split(separator: "/")
        guard components.count >= 2 else { return value }
        if components.count == 2 {
            return "\(components[0])/\(components[1])"
        }
        let owner = components[components.count - 2]
        let name = components[components.count - 1]
        return "\(owner)/\(name)"
    }
}
