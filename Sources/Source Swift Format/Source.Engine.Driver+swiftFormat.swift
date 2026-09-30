extension Source.Engine.Driver {
  public static func swiftFormat(process: Source.Engine.Process) -> Self {
    let id = Source.Engine.ID("swift-format")
    return Self(
      id: id,
      measure: { subject, profile in
        let files = sourceSwiftFormatFiles(subject)
        let result = await process.run(
          profile.executable,
          ["lint", "--strict", "--configuration", profile.configurationPath] + files,
          subject.root,
          profile.environment
        )
        return Source.Measurement.swiftFormat(
          engine: id,
          subject: subject,
          rules: profile.rules,
          status: result.status,
          output: result.output,
          diagnostics: result.diagnostics
        )
      },
      repair: { subject, profile in
        let files = sourceSwiftFormatFiles(subject)
        let lint = await process.run(
          profile.executable,
          ["lint", "--strict", "--configuration", profile.configurationPath] + files,
          subject.root,
          profile.environment
        )
        let measurement = Source.Measurement.swiftFormat(
          engine: id,
          subject: subject,
          rules: profile.rules,
          status: lint.status,
          output: lint.output,
          diagnostics: lint.diagnostics
        )
        guard case .findings(let findings) = measurement.verdict else {
          return .init(edits: [])
        }
        var edits: [Source.Repair.Proposal.Edit] = []
        var refusals: [Source.Reason] = []
        for file in Set(findings.compactMap(\.diagnostic.location.filePath)).sorted() {
          let repair = await process.run(
            profile.executable,
            ["format", "--configuration", profile.configurationPath, file],
            subject.root,
            profile.environment
          )
          guard repair.status == 0, repair.diagnostics.isEmpty else {
            refusals.append(
              .init(
                code: "repair-engine-status",
                detail: "status \(repair.status)" +
                  (repair.diagnostics.isEmpty ? "" : "; stderr: \(repair.diagnostics)")
              )
            )
            continue
          }
          let prefix = subject.root.hasSuffix("/") ? subject.root : subject.root + "/"
          guard file.hasPrefix(prefix),
            let artifact = subject.artifacts.first(where: {
              $0.path == Swift.String(file.dropFirst(prefix.count))
            })
          else {
            refusals.append(.init(code: "repair-file-mismatch", detail: file))
            continue
          }
          edits.append(
            .init(
              path: file,
              expected: artifact.digest.hex,
              replacement: Array(repair.output.utf8)
            )
          )
        }
        return .init(edits: edits, refusals: refusals)
      }
    )
  }
}

internal func sourceSwiftFormatFiles(_ subject: Source.Subject) -> [Swift.String] {
  subject.paths(of: .swift).map { file in
    if file.hasPrefix("/") { return file }
    if subject.root.hasSuffix("/") { return subject.root + file }
    return subject.root + "/" + file
  }.sorted()
}
