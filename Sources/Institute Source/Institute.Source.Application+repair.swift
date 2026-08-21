public import File_System
public import FIPS_180_4
public import Institute_Model
public import JSON
public import Source_Execution
public import Source_Repair

extension Institute.Source.Application {
    public func planRepair(
        workspace: Swift.String,
        configuration: Institute.Configuration,
        cohort: Institute.Source.Workspace.Cohort,
        member: Institute.Source.Workspace.Row,
        rules: Set<SourceDomain.Rule.ID>?,
        preparation: Institute.Source.Preparation
    ) async throws(Institute.Error) -> Institute.Source.Repair.Plan {
        let subject = try subject(for: member)
        let profile = try profile(for: member, preparation: preparation)
        if let rules {
            let available = Set(profile.engines.flatMap(\.rules))
            guard !rules.isEmpty, rules.isSubset(of: available) else {
                throw .configuration("source repair rule selection is empty or unknown")
            }
        }
        let execution = try Self.execution(process: process)
        let measurements = await execution.measure(subject, profile: profile)
        let files = Self.fileSystem(root: subject.root)
        let sourceFiles = try Self.stagedFiles(subject: subject, files: files)
        let sources = SourceDomain.SourceSet.digest(sourceFiles)
        let staging: SourceDomain.Repair.Staging
        do throws(SourceDomain.Reason) {
            staging = try .init(
                subject: subject,
                profile: profile.digest,
                sources: sources,
                measurements: measurements,
                rules: rules,
                fileSystem: files
            )
        } catch { throw .configuration("source repair staging refused: \(error.code): \(error.detail)") }

        let temporary = try Self.temporaryDirectory(beside: subject.root)
        defer {
            do throws(File.System.Delete.Error) { try temporary.delete.recursive() }
            catch {}
        }
        try Self.materialize(staging.files, at: temporary)
        let remapped = Self.remap(process, from: subject.root, to: temporary.description)
        let stagedExecution = try Self.execution(process: remapped)
        let repeated = await stagedExecution.measure(
            subject,
            profile: profile
        )
        let plan = staging.finish(remeasured: repeated)
        return try .init(
            workspace: workspace,
            workspaceDigest: Self.workspaceDigest(workspace),
            inventoryDigest: Self.inventoryDigest(configuration),
            cohort: cohort.admitted.map(\.identity),
            repair: plan
        )
    }

    public func applyRepair(
        _ plan: Institute.Source.Repair.Plan,
        workspace: Swift.String,
        configuration: Institute.Configuration,
        cohort: Institute.Source.Workspace.Cohort,
        preparation: Institute.Source.Preparation
    ) throws(Institute.Error) {
        guard plan.workspace == workspace,
            plan.workspaceDigest == Self.workspaceDigest(workspace),
            plan.inventoryDigest == Self.inventoryDigest(configuration),
            plan.cohort == cohort.admitted.map(\.identity)
        else { throw .configuration("source repair workspace binding is stale") }
        guard let row = cohort.admitted.first(where: { $0.identity == plan.repair.subject.identity }) else {
            throw .configuration("source repair subject is no longer admitted")
        }
        let subject = try subject(for: row)
        let profile = try profile(for: row, preparation: preparation)
        let files = Self.fileSystem(root: subject.root)
        let sources = SourceDomain.SourceSet.digest(try Self.stagedFiles(subject: subject, files: files))
        switch SourceDomain.Repair.Transaction(files: files).apply(
            plan.repair,
            subject: subject.binding,
            profile: profile.digest,
            sources: sources
        ) {
        case .success: return
        case .failure(let reason):
            throw .configuration("source repair apply refused: \(reason.code): \(reason.detail)")
        }
    }

    private static func execution(
        process: SourceDomain.Engine.Process
    ) throws(Institute.Error) -> SourceDomain.Execution {
        do throws(SourceDomain.Execution.Error) { return try executionUnchecked(process: process) }
        catch { throw .configuration("cannot register source engines: \(error)") }
    }

    private static func executionUnchecked(
        process: SourceDomain.Engine.Process
    ) throws(SourceDomain.Execution.Error) -> SourceDomain.Execution {
        try .init(drivers: [.linter(process: process), .swiftFormat(process: process)])
    }

    private static func stagedFiles(
        subject: SourceDomain.Subject,
        files: SourceDomain.Repair.FileSystem
    ) throws(Institute.Error) -> [SourceDomain.Repair.Staged.File] {
        try subject.files.map { path in
            switch files.read(path) {
            case .success(let contents): return .init(path: path, contents: contents)
            case .failure(let reason):
                throw .filesystem("cannot stage \(path): \(reason.code): \(reason.detail)")
            }
        }
    }

    private static func temporaryDirectory(beside root: Swift.String) throws(Institute.Error) -> File.Directory {
        let path: File.Path
        do throws(File.Path.Error) { path = try .init(root) }
        catch { throw .configuration("invalid source member root \(root)") }
        let temporary: File.Path
        do throws(File.Path.Temporary.Error) {
            temporary = try File.Path.Temporary.sibling(
                of: path,
                prefix: ".source-repair-",
                suffix: ".staged"
            )
        } catch { throw .filesystem("cannot allocate source repair staging directory: \(error)") }
        let directory = File.Directory(temporary)
        do throws(File.System.Create.Directory.Error) { try directory.create.recursive() }
        catch { throw .filesystem("cannot create source repair staging directory: \(error)") }
        return directory
    }

    private static func materialize(
        _ files: [SourceDomain.Repair.Staged.File],
        at root: File.Directory
    ) throws(Institute.Error) {
        let fileSystem = Self.fileSystem(root: root.description)
        for file in files {
            guard let contents = file.contents else { continue }
            if case .failure(let reason) = fileSystem.write(file.path, contents) {
                throw .filesystem("cannot materialize \(file.path): \(reason.detail)")
            }
        }
    }

    private static func remap(
        _ process: SourceDomain.Engine.Process,
        from source: Swift.String,
        to staging: Swift.String
    ) -> SourceDomain.Engine.Process {
        .init { executable, arguments, _, environment in
            let rewritten = arguments.map { argument in
                if argument == source { return staging }
                let prefix = source.hasSuffix("/") ? source : source + "/"
                guard argument.hasPrefix(prefix) else { return argument }
                return staging + "/" + argument.dropFirst(prefix.count)
            }
            return await process.run(executable, rewritten, staging, environment)
        }
    }

    private static func workspaceDigest(_ workspace: Swift.String) throws(Institute.Error) -> Swift.String {
        try digest(file: workspace + "/contents.xcworkspacedata").hex
    }

    private static func inventoryDigest(_ configuration: Institute.Configuration) -> Swift.String {
        FIPS_180_4.SHA256.digest(
            configuration.jsonString(sortKeys: true).utf8.map(Byte.init)
        ).hex
    }
}
