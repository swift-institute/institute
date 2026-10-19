public import File_System
public import Institute_Model
public import Institute_Source
public import Institute_Source_Workspace
public import Source_Measurement

extension Institute.Source.Command {
    static func rows(
        at paths: [Swift.String],
        in cohort: Institute.Source.Workspace.Cohort
    ) throws(Institute.Error) -> [Institute.Source.Workspace.Row]? {
        guard !paths.isEmpty else { return nil }
        var selected: Swift.Set<Swift.String> = []
        for path in paths {
            let parsed: File.Path
            do throws(File.Path.Error) { parsed = try .init(path) } catch {
                throw .configuration("invalid --package-path \(path)")
            }
            let canonical: File.Path
            do throws(File.System.Canonical.Error) {
                canonical = try File.System.Canonical.resolve(parsed)
            } catch {
                throw .configuration("cannot resolve --package-path \(path): \(error)")
            }
            guard selected.insert(canonical.description).inserted else {
                throw .configuration("duplicate resolved --package-path \(canonical)")
            }
        }
        let rows = cohort.measurable.filter { selected.contains($0.directory) }
        guard rows.count == selected.count else {
            let measurable = Swift.Set(rows.map(\.directory))
            let unknown = selected.subtracting(measurable).sorted().joined(separator: ", ")
            throw .configuration(
                "--package-path is not a measurable direct workspace member: \(unknown)"
            )
        }
        return rows
    }

    static func rules(
        _ values: [Swift.String]
    ) throws(Institute.Error)
        -> Swift.Set<Source_Measurement.Source.Rule.ID>?
    {
        guard !values.isEmpty else { return nil }
        var rules: Swift.Set<Source_Measurement.Source.Rule.ID> = []
        for value in values {
            let fields = value.split(
                separator: ":",
                maxSplits: 1,
                omittingEmptySubsequences: false
            )
            guard fields.count == 2, !fields[0].isEmpty, !fields[1].isEmpty else {
                throw .configuration("invalid --rule \(value); expected <engine>:<rule>")
            }
            let rule = Source_Measurement.Source.Rule.ID(
                engine: .init(Swift.String(fields[0])),
                token: Swift.String(fields[1])
            )
            guard rules.insert(rule).inserted else {
                throw .configuration("duplicate --rule \(value)")
            }
        }
        return rules
    }
}
