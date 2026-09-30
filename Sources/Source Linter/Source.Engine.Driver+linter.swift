extension Source.Engine.Driver {
  public static func linter(process: Source.Engine.Process) -> Self {
    let id = Source.Engine.ID("swift-linter")
    return Self(
      id: id,
      measure: { subject, profile in
        let result = await process.run(
          profile.executable,
          ["--profile", profile.configurationPath, subject.root],
          subject.root,
          profile.environment.merging(
            [
              "SWIFT_LINTER_FORMAT": "structured",
              "SWIFT_LINTER_EXIT_POLICY": "strict",
            ],
            uniquingKeysWith: { _, required in required }
          )
        )
        return Source.Measurement.linter(
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
          refusals: [.init(code: "unsupported", detail: "linter proposal unavailable")]
        )
      }
    )
  }
}
