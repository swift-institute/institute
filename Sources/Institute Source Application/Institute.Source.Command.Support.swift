public import File_System
public import Institute_Model
public import Institute_Source
public import Institute_Source_Workspace
public import JSON
public import Source_Repair
public import Source_Report

extension Institute.Source.Command {
    static func context(
        workspace: Swift.String
    ) throws(Institute.Error) -> (
        root: Institute.Root,
        configuration: Institute.Configuration,
        cohort: Institute.Source.Workspace.Cohort
    ) {
        guard !workspace.isEmpty else { throw .configuration("--workspace-path is required") }
        let workspacePath: File.Path
        do throws(File.Path.Error) { workspacePath = try .init(workspace) } catch {
            throw .configuration("invalid --workspace-path \(workspace)")
        }
        guard let checkout = File.Directory(workspacePath).parent else {
            throw .configuration("workspace has no containing Institute checkout")
        }
        let root = try Institute.Root(checkout: checkout)
        let configuration = try Institute.Configuration.load(at: root.checkout)
        return (
            root,
            configuration,
            try Institute.Source.Workspace.Cohort.read(
                from: workspace,
                configuration: configuration,
                hierarchy: root.hierarchy
            )
        )
    }

    static func preparation(
        workspace: Swift.String
    ) throws(Institute.Error)
        -> Institute.Source.Preparation
    {
        try Institute.Source.Preparation.read(workspace: workspace)
    }

    static func write(_ contents: Swift.String, to output: Swift.String) throws(Institute.Error) {
        guard !output.isEmpty else {
            print(contents, terminator: "")
            return
        }
        let path: File.Path
        do throws(File.Path.Error) { path = try .init(output) } catch {
            throw .configuration("invalid --output-path \(output)")
        }
        do throws(File.System.Write.Atomic.Error) { try File(path).write.atomic(contents) } catch {
            throw .filesystem("cannot write --output-path \(output): \(error)")
        }
    }

    static func repairPlan(
        at path: Swift.String
    ) throws(Institute.Error)
        -> Institute.Source.Repair.Plan
    {
        let contents = try read(path)
        do throws(JSON.Error) {
            return try .init(jsonString: contents)
        } catch {
            throw .configuration("source repair plan is malformed: \(error)")
        }
    }

    static func write(
        _ plan: Institute.Source.Repair.Plan,
        to output: Swift.String
    ) throws(Institute.Error) {
        let file = try outputFile(output)
        if file.stat.exists {
            let existing = try repairPlan(at: output)
            guard existing.workspace == plan.workspace,
                existing.cohort == plan.cohort,
                existing.repairs.map(\.subject) == plan.repairs.map(\.subject)
            else {
                throw .configuration(
                    "--output-path contains a repair plan for a different workspace or subject"
                )
            }
        }
        try atomic(plan.jsonString(sortKeys: true) + "\n", to: file)
    }

    static func write(
        _ report: Source_Report.Source.Report,
        format: Institute.Source.Command.Measure.Format,
        to output: Swift.String
    ) throws(Institute.Error) {
        let rendered =
            format == .json
            ? report.jsonString(sortKeys: true) + "\n"
            : report.human
        guard !output.isEmpty else {
            print(rendered, terminator: "")
            return
        }
        let file = try outputFile(output)
        if file.stat.exists {
            switch format {
            case .json:
                let existing: Source_Report.Source.Report
                let contents = try read(output)
                do throws(JSON.Error) { existing = try .init(jsonString: contents) } catch {
                    throw .configuration("existing source report is malformed: \(error)")
                }
                guard existing.subjects.map(\.binding) == report.subjects.map(\.binding) else {
                    throw .configuration(
                        "--output-path contains a source report for different subjects"
                    )
                }
            case .human:
                guard try read(output) == rendered else {
                    throw .configuration(
                        "cannot validate replacement of a changed human source report; use --format json"
                    )
                }
            }
        }
        try atomic(rendered, to: file)
    }

    private static func read(_ path: Swift.String) throws(Institute.Error) -> Swift.String {
        let file = try outputFile(path)
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try File.System.Read.Full.read(from: file.path) { span in
                var bytes: [Byte] = []
                bytes.reserveCapacity(span.count)
                for index in span.indices { bytes.append(span[index]) }
                return Swift.String(decoding: bytes, as: Swift.UTF8.self)
            }
        } catch { throw .filesystem("cannot read artifact \(path): \(error)") }
    }

    private static func outputFile(_ output: Swift.String) throws(Institute.Error) -> File {
        guard !output.isEmpty else { throw .configuration("--output-path is required") }
        do throws(File.Path.Error) { return try File(.init(output)) } catch {
            throw .configuration("invalid artifact path \(output)")
        }
    }

    private static func atomic(_ contents: Swift.String, to file: File) throws(Institute.Error) {
        do throws(File.System.Write.Atomic.Error) { try file.write.atomic(contents) } catch {
            throw .filesystem("cannot write artifact \(file): \(error)")
        }
    }
}
