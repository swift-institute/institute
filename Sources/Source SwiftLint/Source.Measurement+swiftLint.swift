internal import JSON

extension Source.Measurement {
  public static func swiftLint(
    engine: Source.Engine.ID,
    subject: Source.Subject,
    rules: [Source.Rule.ID],
    status: Swift.Int32,
    output: Swift.String,
    diagnostics: Swift.String
  ) -> Self {
    let files = sourceSwiftLintFiles(subject)
    guard !files.isEmpty else {
      return sourceSwiftLintUnmeasured(
        engine: engine,
        subject: subject,
        rules: rules,
        files: files,
        code: "zero-files",
        detail: "no source files"
      )
    }
    guard !rules.isEmpty else {
      return sourceSwiftLintUnmeasured(
        engine: engine,
        subject: subject,
        rules: rules,
        files: files,
        code: "zero-rules",
        detail: "no active rules"
      )
    }
    let canonicalRules = rules.sorted { $0.token < $1.token }
    guard canonicalRules == rules,
      Swift.Set(rules).count == rules.count,
      rules.allSatisfy({ $0.engine == engine && !$0.token.isEmpty })
    else {
      return sourceSwiftLintUnmeasured(
        engine: engine,
        subject: subject,
        rules: rules,
        files: files,
        code: "rule-profile",
        detail: "swiftlint rules must be unique, canonical, and owned by the engine"
      )
    }
    guard diagnostics.isEmpty else {
      return sourceSwiftLintUnmeasured(
        engine: engine,
        subject: subject,
        rules: rules,
        files: files,
        code: "unexpected-diagnostics",
        detail: diagnostics
      )
    }
    do throws(Source.Reason) {
      return try sourceSwiftLintMeasurement(
        engine: engine,
        subject: subject,
        rules: rules,
        files: files,
        status: status,
        output: output
      )
    } catch {
      return sourceSwiftLintUnmeasured(
        engine: engine,
        subject: subject,
        rules: rules,
        files: files,
        code: error.code,
        detail: error.detail
      )
    }
  }
}

private func sourceSwiftLintMeasurement(
  engine: Source.Engine.ID,
  subject: Source.Subject,
  rules: [Source.Rule.ID],
  files: [Swift.String],
  status: Swift.Int32,
  output: Swift.String
) throws(Source.Reason) -> Source.Measurement {
  let document: JSON
  do throws(JSON.Error) {
    document = try JSON.parse(output)
  } catch {
    throw .init(code: "malformed-output", detail: Swift.String(describing: error))
  }
  guard let records = document.array else {
    throw .init(code: "malformed-output", detail: "swiftlint output must be an array")
  }

  let ruleTokens = Swift.Set(rules.map(\.token))
  var findings: [Source.Finding] = []
  findings.reserveCapacity(records.count)
  for record in records {
    guard let object = record.dictionary else {
      throw .init(code: "malformed-output", detail: "finding must be an object")
    }
    let expected: Swift.Set<Swift.String> = [
      "character", "file", "line", "reason", "rule_id", "severity", "type",
    ]
    guard Swift.Set(object.keys) == expected else {
      throw .init(code: "unconsumed-output", detail: "swiftlint finding keys differ")
    }
    guard let fileJSON = object["file"],
      let lineJSON = object["line"],
      let characterJSON = object["character"],
      let reasonJSON = object["reason"],
      let ruleJSON = object["rule_id"],
      let severityJSON = object["severity"],
      let typeJSON = object["type"]
    else {
      throw .init(code: "unconsumed-output", detail: "swiftlint finding is incomplete")
    }
    let file = try sourceSwiftLintString(fileJSON, field: "file")
    guard files.contains(file) else {
      throw .init(code: "file-mismatch", detail: file)
    }
    let token = try sourceSwiftLintString(ruleJSON, field: "rule_id")
    guard ruleTokens.contains(token) else {
      throw .init(code: "rule-mismatch", detail: token)
    }
    let line = try sourceSwiftLintInt(lineJSON, field: "line")
    guard line > 0 else {
      throw .init(code: "finding-location", detail: "line must be positive")
    }
    let column: Swift.Int
    if characterJSON.isNull {
      column = 1
    } else {
      column = try sourceSwiftLintInt(characterJSON, field: "character")
      guard column > 0 else {
        throw .init(code: "finding-location", detail: "character must be positive or null")
      }
    }
    let severity: Diagnostic.Severity
    switch try sourceSwiftLintString(severityJSON, field: "severity") {
    case "Error": severity = .error
    case "Warning": severity = .warning
    default: throw .init(code: "finding-severity", detail: "unknown swiftlint severity")
    }
    let message = try sourceSwiftLintString(reasonJSON, field: "reason")
    let type = try sourceSwiftLintString(typeJSON, field: "type")
    guard !message.isEmpty, !type.isEmpty else {
      throw .init(code: "finding-content", detail: "reason and type must be nonempty")
    }
    findings.append(
      .init(
        rule: .init(engine: engine, token: token),
        diagnostic: .init(
          location: .init(
            fileID: file,
            filePath: file,
            line: line,
            column: column
          ),
          severity: severity,
          identifier: token,
          message: message
        ),
        repair: .unavailable(
          .init(code: "repair-evidence-unavailable", detail: file)
        )
      )
    )
  }
  guard Swift.Set(findings).count == findings.count else {
    throw .init(code: "duplicate-finding", detail: "swiftlint repeated a finding")
  }
  findings.sort {
    let left = $0.diagnostic.location
    let right = $1.diagnostic.location
    return (left.filePath ?? left.fileID, left.line, left.column, $0.rule.token)
      < (right.filePath ?? right.fileID, right.line, right.column, $1.rule.token)
  }

  let expectedStatus: Swift.Int32 = findings.isEmpty ? 0 : 2
  guard status == expectedStatus else {
    throw .init(
      code: "engine-status-mismatch",
      detail: "expected status \(expectedStatus), received \(status)"
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
  return .init(
    engine: engine,
    subject: subject,
    activeRules: rules,
    applicableRules: rules,
    files: files,
    observations: observations,
    verdict: findings.isEmpty ? .clean : .findings(findings)
  )
}

private func sourceSwiftLintString(
  _ json: JSON,
  field: Swift.String
) throws(Source.Reason) -> Swift.String {
  do throws(JSON.Error) {
    return try Swift.String(json: json)
  } catch {
    throw .init(code: "malformed-output", detail: "\(field) is not a string")
  }
}

private func sourceSwiftLintInt(
  _ json: JSON,
  field: Swift.String
) throws(Source.Reason) -> Swift.Int {
  do throws(JSON.Error) {
    return try Swift.Int(json: json)
  } catch {
    throw .init(code: "malformed-output", detail: "\(field) is not an integer")
  }
}

private func sourceSwiftLintUnmeasured(
  engine: Source.Engine.ID,
  subject: Source.Subject,
  rules: [Source.Rule.ID],
  files: [Swift.String],
  code: Swift.String,
  detail: Swift.String
) -> Source.Measurement {
  .init(
    engine: engine,
    subject: subject,
    activeRules: rules,
    applicableRules: [],
    files: files,
    verdict: .unmeasured([.init(code: code, detail: detail)])
  )
}
