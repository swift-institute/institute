public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Source_Profile

extension Institute.Source.Application {
    func profile(
        for row: Institute.Source.Workspace.Row,
        preparation: Institute.Source.Preparation
    ) throws(Institute.Error) -> SourceDomain.Profile {
        guard let repository = row.repository else {
            throw .configuration("source member is not admitted: \(row.identity)")
        }
        let policy = ContinuousIntegration.Source.Policy.current
        let owner = Institute.Source.Profile(policy: policy)
        let bundle = owner.bundle(for: repository)
        let rules = owner.rules(for: bundle)
        let linterConfiguration =
            "\(preparation.directory)/\(bundle.rawValue)-source-linter-profile.json"
        let artifact = policy.linter(bundle: bundle, rules: rules)
        guard Self.matches(file: linterConfiguration, digest: artifact.digest) else {
            throw .configuration("source linter configuration is stale for \(bundle.rawValue)")
        }
        let profile = policy.profile(
            swiftFormatExecutable: preparation.swiftFormatExecutable,
            swiftFormatTool: preparation.swiftFormatTool,
            swiftFormatConfigurationPath: "\(preparation.directory)/.swift-format",
            linterExecutable: preparation.linterExecutable,
            linterTool: preparation.linterTool,
            linterConfigurationPath: linterConfiguration,
            bundle: bundle,
            linterRules: rules
        )
        guard preparation.profiles[bundle.rawValue] == profile.digest else {
            throw .configuration("source profile is stale for \(bundle.rawValue)")
        }
        return profile
    }
}
