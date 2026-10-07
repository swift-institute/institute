extension Source.Repair.Evidence {
  public static func refusals(for findings: [Source.Finding]) -> [Self] {
    var keys: Swift.Set<Swift.String> = []
    var evidence: [Self] = []
    for finding in findings {
      guard case .unavailable(let reason) = finding.repair,
        let file = finding.diagnostic.location.filePath,
        keys.insert(file + "\u{0}" + finding.rule.engine.token + "\u{0}" + finding.rule.token)
          .inserted
      else { continue }
      evidence.append(.init(file: file, rule: finding.rule, disposition: .refused(reason)))
    }
    return evidence
  }
}
