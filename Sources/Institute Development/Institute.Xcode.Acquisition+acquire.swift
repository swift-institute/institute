public import Async_Fanout
internal import File_System
public import Institute_Model
internal import Institute_Source_Workspace
public import Package_Manager
internal import Source_Measurement
internal import Xcode_Workspace

extension Institute.Xcode.Acquisition {
    public static func acquire(
        _ specification: Institute.Workspace.Specification,
        at root: Institute.Root,
        packages: Package.Manager = .init(),
        fanout: Async.Fanout = .init(jobs: 32),
        timeout: Swift.Duration = .seconds(120)
    ) async throws(Institute.Error) -> Institute.Xcode.Catalog {
        var inputs = [
            (
                index: Swift.Int,
                member: Institute.Workspace.Member,
                directory: File.Directory,
                location: Xcode_Workspace.Xcode.Workspace.Location,
                reference: Swift.String
            )
        ]()
        inputs.reserveCapacity(specification.members.count)
        for (index, member) in specification.members.enumerated() {
            let directory = try directory(for: member, at: root)
            guard directory[file: "Package.swift"].stat.isFile else {
                throw .configuration("workspace member has no Package.swift: \(member.location)")
            }
            guard
                let location = Xcode_Workspace.Xcode.Workspace.Location(
                    rawValue: member.location
                )
            else {
                throw .configuration("invalid workspace member location: \(member.location)")
            }
            inputs.append(
                (
                    index: index,
                    member: member,
                    directory: directory,
                    location: location,
                    reference: location.path
                )
            )
        }
        let acquisitionInputs = inputs

        return try await withScratch(at: root) {
            (scratch: File.Directory) async throws(Institute.Error) -> Institute.Xcode.Catalog in
            let observations = await fanout.map(acquisitionInputs) { input in
                let clock = Swift.ContinuousClock()
                let started = clock.now
                let result: Swift.Result<Observation.Payload, Institute.Error>
                do throws(Institute.Error) {
                    let row = Institute.Source.Workspace.Row(
                        index: input.index,
                        location: input.location,
                        directory: input.directory.description,
                        identity: identity(for: input.member),
                        role: input.member.role,
                        repository: nil,
                        reason: nil
                    )
                    let before = try Institute.Source.Workspace.subject(for: row, paths: [])
                    let catalog: Package.Manager.Catalog
                    do throws(Package.Manager.Error) {
                        catalog = try packages.catalog(
                            at: input.directory.description,
                            timeout: timeout,
                            scratch: scratch[directory: "\(input.index)"].description
                        )
                    } catch {
                        throw .configuration("package catalog failed: \(error)")
                    }
                    let after = try Institute.Source.Workspace.subject(for: row, paths: [])
                    guard before == after else {
                        throw .configuration(
                            "source/package inputs changed while acquiring \(row.identity)"
                        )
                    }
                    result = .success(.init(catalog: catalog, sources: after.artifacts))
                } catch {
                    result = .failure(error)
                }
                return Observation(
                    index: input.index,
                    member: input.member,
                    reference: input.reference,
                    duration: clock.now - started,
                    result: result
                )
            }
            guard observations.count == acquisitionInputs.count else {
                throw .configuration(
                    "target catalog acquisition returned \(observations.count) observations for "
                        + "\(acquisitionInputs.count) workspace members"
                )
            }

            var entries = [Institute.Xcode.Catalog.Entry]()
            entries.reserveCapacity(observations.count)
            for observation in observations.sorted(by: { $0.index < $1.index }) {
                let payload: Observation.Payload
                switch observation.result {
                case .success(let value):
                    payload = value

                case .failure(let error):
                    throw .configuration(
                        "cannot acquire target catalog for \(observation.identity) at "
                            + "\(observation.reference) within \(timeout) "
                            + "(observed \(observation.duration)): \(error)"
                    )
                }
                entries.append(
                    .init(
                        member: observation.member,
                        reference: observation.reference,
                        manifest: payload.catalog.manifest,
                        toolchain: payload.catalog.toolchain,
                        targets: payload.catalog.evaluation.targets,
                        sources: payload.sources
                    )
                )
            }
            guard entries.map(\.member) == specification.members else {
                throw .configuration(
                    "target catalog acquisition changed workspace member order or identity"
                )
            }
            guard Set(entries.map(\.toolchain)).count == 1 else {
                throw .configuration(
                    "workspace target catalogs were acquired by multiple toolchains")
            }
            return .init(entries: entries)
        }
    }

    private static func identity(for member: Institute.Workspace.Member) -> Swift.String {
        switch member.role {
        case .subject(let repository): repository.identity
        case .control(let control): "control:\(control.rawValue)"
        }
    }

    private static func directory(
        for member: Institute.Workspace.Member,
        at root: Institute.Root
    ) throws(Institute.Error) -> File.Directory {
        guard let location = Xcode_Workspace.Xcode.Workspace.Location(rawValue: member.location),
            location.scheme == .group || location.scheme == .container,
            let relative = try? File.Path(location.path)
        else { throw .configuration("invalid workspace member location: \(member.location)") }
        return File.Directory(root.checkout.path / relative)
    }
}

extension Institute.Xcode.Acquisition.Observation {
    var identity: Swift.String {
        switch member.role {
        case .subject(let repository): repository.identity
        case .control(let control): "control:\(control.rawValue)"
        }
    }
}
