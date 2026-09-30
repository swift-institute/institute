extension Source.Engine.Driver {
  public static func swiftLint(process: Source.Engine.Process) -> Self {
    let id = Source.Engine.ID("swiftlint")
    return Self(
      id: id,
      measure: { subject, profile in
        let files = sourceSwiftLintFiles(subject)
        let arguments =
          [
            "lint",
            "--strict",
            "--reporter", "json",
            "--quiet",
            "--no-cache",
            "--silence-deprecation-warnings",
            "--config", profile.configurationPath,
          ]
          + profile.rules.flatMap { ["--only-rule", $0.token] }
          + files
        let result = await process.run(
          profile.executable,
          arguments,
          subject.root,
          profile.environment
        )
        return Source.Measurement.swiftLint(
          engine: id,
          subject: subject,
          rules: profile.rules,
          status: result.status,
          output: result.output,
          diagnostics: result.diagnostics
        )
      },
      repair: { _, _ in
        .init(
          edits: [],
          refusals: [
            .init(code: "unsupported", detail: "swiftlint proposal unavailable")
          ]
        )
      }
    )
  }
}

internal func sourceSwiftLintFiles(_ subject: Source.Subject) -> [Swift.String] {
  subject.paths(of: .swift).map { file in
    if file.hasPrefix("/") { return file }
    if subject.root.hasSuffix("/") { return subject.root + file }
    return subject.root + "/" + file
  }.sorted()
}
