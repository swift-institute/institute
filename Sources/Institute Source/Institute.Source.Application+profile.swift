public import Institute_Source_Policy
public import Institute_Model
internal import Institute_Source_Profile
internal import Institute_Source_Workspace
public import Source_Profile

extension Institute.Source.Application {
  func profile(
    for row: Institute.Source.Workspace.Row,
    preparation: Institute.Source.Preparation
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
    guard
      Self.matches(
        file: "\(preparation.directory)/.swift-format",
        digest: policy.swiftFormat.digest
      ),
      Self.matches(
        file: "\(preparation.directory)/.swiftlint.yml",
        digest: policy.swiftLint.digest
      )
    else { throw .configuration("source preparation configuration is stale") }
    let owner = Institute.Source.Profile(policy: policy)
    let bundle = try owner.bundle(for: row)
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
      swiftLintExecutable: preparation.swiftLintExecutable,
      swiftLintTool: preparation.swiftLintTool,
      swiftLintConfigurationPath: "\(preparation.directory)/.swiftlint.yml",
      swiftLintRules: preparation.swiftLintRules,
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
