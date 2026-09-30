extension Source.Measurement {
  public static func swiftFormat(
    engine: Source.Engine.ID,
    subject: Source.Subject,
    rules: [Source.Rule.ID],
    status: Swift.Int32,
    output: Swift.String,
    diagnostics: Swift.String
  ) -> Self {
    let files = sourceSwiftFormatFiles(subject)
    guard !files.isEmpty else {
      return sourceSwiftFormatUnmeasured(engine, subject, rules, "zero-files", "no files")
    }
    guard rules.count == 1, rules[0].engine == engine, rules[0].token == "format" else {
      return sourceSwiftFormatUnmeasured(
        engine,
        subject,
        rules,
        "rule-profile",
        "swift-format requires its format predicate"
      )
    }
    guard output.isEmpty else {
      return sourceSwiftFormatUnmeasured(
        engine,
        subject,
        rules,
        "unexpected-output",
        "swift-format wrote stdout"
      )
    }
    guard status == 0 || status == 1 else {
      return sourceSwiftFormatUnmeasured(
        engine,
        subject,
        rules,
        "engine-status",
        "status \(status)"
      )
    }

    var findings: [Source.Finding] = []
    let lines = diagnostics.split(separator: "\n", omittingEmptySubsequences: true)
    for line in lines {
      guard
        let finding = sourceSwiftFormatFinding(
          Swift.String(line),
          engine: engine,
          files: files,
          rules: rules
        )
      else {
        return sourceSwiftFormatUnmeasured(
          engine,
          subject,
          rules,
          "malformed-output",
          Swift.String(line)
        )
      }
      findings.append(finding)
    }
    guard (status == 0) == findings.isEmpty else {
      return sourceSwiftFormatUnmeasured(
        engine,
        subject,
        rules,
        "engine-status-mismatch",
        "status and findings disagree"
      )
    }
    let observations = files.flatMap { file in
      rules.map { rule in
        Source.Rule.Observation(
          file: file,
          rule: rule,
          applicable: true,
          coverage: .measured
        )
      }
    }
    return Self(
      engine: engine,
      subject: subject,
      activeRules: rules,
      applicableRules: rules,
      files: files,
      observations: observations,
      verdict: findings.isEmpty ? .clean : .findings(findings)
    )
  }
}

private func sourceSwiftFormatFinding(
  _ line: Swift.String,
  engine: Source.Engine.ID,
  files: [Swift.String],
  rules: [Source.Rule.ID]
) -> Source.Finding? {
  let fields = line.split(separator: ":", maxSplits: 4, omittingEmptySubsequences: false)
  guard fields.count == 5,
    let lineNumber = Swift.Int(fields[1]), lineNumber > 0,
    let column = Swift.Int(fields[2]), column > 0
  else { return nil }
  let file = Swift.String(fields[0])
  guard files.contains(file), sourceSwiftFormatTrim(fields[3]) == "error" else { return nil }
  let message = sourceSwiftFormatTrim(fields[4])
  guard message.first == "[", let end = message.firstIndex(of: "]") else { return nil }
  let token = Swift.String(message[message.index(after: message.startIndex)..<end])
  guard rules.count == 1 else { return nil }
  let rule = rules[0]
  let detail = sourceSwiftFormatTrim(message[message.index(after: end)...])
  return Source.Finding(
    rule: rule,
    diagnostic: .init(
      location: .init(
        fileID: file,
        filePath: file,
        line: lineNumber,
        column: column
      ),
      severity: .error,
      identifier: token,
      message: detail
    ),
    repair: .unavailable(.init(code: "repair-evidence-unavailable", detail: file))
  )
}

private func sourceSwiftFormatTrim<S: Swift.StringProtocol>(_ value: S) -> Swift.String {
  Swift.String(value.drop(while: { $0 == " " || $0 == "\t" }))
}

private func sourceSwiftFormatUnmeasured(
  _ engine: Source.Engine.ID,
  _ subject: Source.Subject,
  _ rules: [Source.Rule.ID],
  _ code: Swift.String,
  _ detail: Swift.String
) -> Source.Measurement {
  .init(
    engine: engine,
    subject: subject,
    activeRules: rules,
    applicableRules: [],
    files: subject.paths(of: .swift),
    verdict: .unmeasured([.init(code: code, detail: detail)])
  )
}
