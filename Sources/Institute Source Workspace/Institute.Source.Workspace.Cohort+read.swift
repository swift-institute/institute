internal import Byte_Primitives
public import File_System
public import Institute_Model
internal import JSON
internal import Source_Measurement
internal import Xcode_Workspace

extension Institute.Source.Workspace.Cohort {
    public static func read(
        from workspace: Swift.String,
        configuration: Institute.Configuration,
        hierarchy: File.Directory
    ) throws(Institute.Error) -> Self {
        let specification = try Self.specification(from: workspace)
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
        var reasons: [Source_Measurement.Source.Reason] = []
        for reference in document.references {
            Self.flatten(
                reference,
                group: container,
                container: container,
                into: &flattened,
                reasons: &reasons
            )
        }
        let actualLocations = flattened.map(\.0.rawValue)
        let specifiedLocations = specification.members.map(\.location)
        guard actualLocations == specifiedLocations else {
            throw .configuration(
                "source workspace XML and typed membership specification disagree"
            )
        }

        var rows: [Institute.Source.Workspace.Row] = []
        var canonicalPaths: Swift.Set<Swift.String> = []
        var groupCount = 0
        var containerCount = 0
        for (index, pair) in Swift.zip(flattened, specification.members).enumerated() {
            let entry = pair.0
            let member = pair.1
            switch entry.0.scheme {
            case .group: groupCount += 1
            case .container: containerCount += 1
            case .absolute, .self, .other: break
            }
            let canonical: File.Path
            do throws(File.System.Canonical.Error) {
                canonical = try File.System.Canonical.resolve(entry.1.path)
            } catch {
                let reason = Source_Measurement.Source.Reason(
                    code: "unresolved-reference",
                    detail: entry.0.rawValue
                )
                reasons.append(reason)
                rows.append(
                    .init(
                        index: index,
                        location: entry.0,
                        directory: entry.1.description,
                        identity: Self.identity(member.role),
                        role: member.role,
                        repository: nil,
                        reason: reason
                    )
                )
                continue
            }
            let identity = Self.identity(member.role)
            let duplicate = !canonicalPaths.insert(canonical.description).inserted
            let manifest = File.Directory(canonical)[file: "Package.swift"].stat.isFile
            let repository: Institute.Repository?
            switch member.role {
            case .subject(let key):
                let candidate = expected[canonical.description]
                repository = candidate.flatMap {
                    Institute.Repository.Key(repository: $0) == key ? $0 : nil
                }
            case .control:
                repository = nil
            }
            let reason: Source_Measurement.Source.Reason?
            if duplicate {
                reason = .init(code: "duplicate-reference", detail: canonical.description)
            } else if !manifest {
                reason = .init(code: "missing-manifest", detail: canonical.description)
            } else if case .subject = member.role, repository == nil {
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
                    role: member.role,
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

    private static func specification(
        from workspace: Swift.String
    ) throws(Institute.Error) -> Institute.Workspace.Specification {
        let bundle: File.Path
        do throws(File.Path.Error) { bundle = try .init(workspace) }
        catch { throw .configuration("invalid source workspace path \(workspace)") }
        let file = File.Directory(bundle)[directory: "xcshareddata"][
            file: "Institute.workspace.json"
        ]
        let contents: Swift.String
        do throws(Either<File.System.Read.Full.Error, Never>) {
            contents = try file.read.full { bytes in
                var storage: [Byte] = []
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices { storage.append(bytes[index]) }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            throw .configuration("source workspace membership specification is missing")
        }
        do throws(JSON.Error) {
            return try .init(jsonString: contents)
        } catch {
            throw .configuration("source workspace membership specification is malformed: \(error)")
        }
    }

    private static func identity(_ role: Institute.Workspace.Role) -> Swift.String {
        switch role {
        case .subject(let repository): return repository.identity
        case .control(let control): return "control:\(control.rawValue)"
        }
    }

    private static func flatten(
        _ reference: Xcode.Workspace.Reference,
        group: File.Directory,
        container: File.Directory,
        into entries: inout [(Xcode.Workspace.Location, File.Directory)],
        reasons: inout [Source_Measurement.Source.Reason]
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

}
