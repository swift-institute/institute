public import Institute_Model
public import Institute_Source_Policy
internal import Institute_Source_Profile
internal import Institute_Source_Workspace
public import Source_Profile

extension Institute.Source.Application {
    func profile(
        for row: Institute.Source.Workspace.Row,
        preparation: Institute.Source.Preparation,
        repair: Swift.Bool = false
    ) throws(Institute.Error) -> Source_Profile.Source.Profile {
        let policy = Institute.Source.Policy.current
        guard preparation.policyRevision == policy.revision else {
            throw .configuration("source preparation policy is stale")
        }
        guard
            Self.matches(file: preparation.swiftFormatExecutable, digest: preparation.swiftFormatTool),
            Self.matches(file: preparation.swiftLintExecutable, digest: preparation.swiftLintTool),
            Self.matches(file: preparation.linterExecutable, digest: preparation.linterTool)
        else { throw .configuration("source preparation tool is stale") }
        let formatArtifact = repair ? policy.swiftFormatRepair : policy.swiftFormat
        let formatConfiguration = "\(preparation.directory)/\(formatArtifact.path)"
        guard
            Self.matches(
                file: formatConfiguration,
                digest: formatArtifact.digest
            )
        else { throw .configuration("source preparation configuration is stale") }
        let swiftLintConfiguration = "\(preparation.directory)/\(policy.swiftLint.path)"
        guard Self.matches(file: swiftLintConfiguration, digest: policy.swiftLint.digest) else {
            throw .configuration("source SwiftLint configuration is stale")
        }
        let owner = Institute.Source.Profile(policy: policy)
        let bundle = try owner.bundle(for: row)
        guard preparation.verifiedProfiles.contains(bundle.rawValue) else {
            throw .configuration(
                "source linter profile for \(bundle.rawValue) has no parse receipt"
            )
        }
        let rules = owner.rules(for: bundle)
        let linterConfiguration =
            "\(preparation.directory)/\(bundle.rawValue)-source-linter-profile.json"
        let artifact = policy.linter(bundle: bundle, rules: rules)
        guard Self.matches(file: linterConfiguration, digest: artifact.digest) else {
            throw .configuration("source linter configuration is stale for \(bundle.rawValue)")
        }
        let profile = policy.profile(
            swiftFormat: (executable: preparation.swiftFormatExecutable, tool: preparation.swiftFormatTool, configurationPath: formatConfiguration),
            swiftLint: (executable: preparation.swiftLintExecutable, tool: preparation.swiftLintTool, configurationPath: swiftLintConfiguration),
            linter: (executable: preparation.linterExecutable, tool: preparation.linterTool, configurationPath: linterConfiguration),
            bundle: bundle,
            linterRules: rules,
            repair: repair
        )
        if !repair {
            guard preparation.profiles[bundle.rawValue] == profile.digest else {
                throw .configuration("source profile is stale for \(bundle.rawValue)")
            }
        }
        return profile
    }
}
