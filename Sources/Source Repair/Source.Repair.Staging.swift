extension Source.Repair {
  public struct Staging: Sendable {
    public let subject: Source.Subject
    public let binding: Source.Subject.Binding
    public let profile: Source.Profile.Digest
    public let sources: Source.SourceSet.Digest
    public let files: [Staged.File]
    public let operations: [Operation]
    public let refusals: [Refusal]
    private let engines: Swift.Set<Source.Engine.ID>
    private let selectedEvidence: Swift.Set<Source.Repair.Evidence.ID>

    public init(
      subject: Source.Subject,
      profile: Source.Profile.Digest,
      sources: Source.SourceSet.Digest,
      measurements: [Source.Measurement],
      selection: Source.Repair.Selection,
      fileSystem: FileSystem
    ) throws(Source.Reason) {
      var staged: [Swift.String: Staged.File] = [:]
      for path in subject.paths(of: .swift) {
        let relative = try Self.relative(path, root: subject.root)
        guard staged[relative] == nil else {
          throw .init(code: "path-collision", detail: relative)
        }
        switch fileSystem.read(relative) {
        case .success(let contents):
          staged[relative] = .init(path: relative, contents: contents)
        case .failure(let reason): throw reason
        }
      }
      let initial = staged.values.sorted(by: { $0.path < $1.path })
      guard Source.SourceSet.digest(initial) == sources else {
        throw .init(code: "stale-sources", detail: sources.hex)
      }

      if let rules = selection.automaticRules, rules.isEmpty {
        throw .init(code: "repair-selection", detail: "automatic rule selection is empty")
      }
      var selectedEvidence: Swift.Set<Source.Repair.Evidence.ID> = []
      for measurement in measurements {
        guard case .findings(let findings) = measurement.verdict else { continue }
        for finding in findings
        where (selection.automaticRules?.contains(finding.rule) ?? true)
          && finding.repair == .automatic
        {
          selectedEvidence.insert(Self.id(finding))
        }
      }

      var operations: [Operation] = []
      var refusals: [Refusal] = []
      var affected: Swift.Set<Swift.String> = []
      var observedEvidence: Swift.Set<Source.Repair.Evidence.ID> = []
      let sorted = measurements.sorted {
        (Self.rank($0.engine), $0.engine.token) < (Self.rank($1.engine), $1.engine.token)
      }
      let engines = Swift.Set(sorted.map(\.engine))
      guard engines.count == sorted.count else {
        throw .init(code: "duplicate-engine", detail: subject.identity)
      }
      for measurement in sorted {
        guard measurement.subject == subject else {
          throw .init(code: "stale-subject", detail: measurement.subject.identity)
        }
        let suppressions = measurement.suppressions.filter {
          selectedEvidence.contains(Self.id($0))
        }
        if !suppressions.isEmpty {
          refusals.append(.init(.init(code: "suppression", detail: measurement.engine.token)))
        }
        switch measurement.verdict {
        case .unmeasured(let reasons): refusals.append(contentsOf: reasons.map(Refusal.init))
        case .notRequested:
          refusals.append(.init(.init(code: "not-requested", detail: measurement.engine.token)))
        case .clean:
          guard measurement.repairs.filter({ selectedEvidence.contains($0.id) }).isEmpty
          else {
            refusals.append(.init(.init(code: "non-idempotent", detail: measurement.engine.token)))
            continue
          }
        case .findings: break
        }
        for evidence in measurement.repairs
        where selectedEvidence.contains(evidence.id) {
          observedEvidence.insert(evidence.id)
          switch evidence.disposition {
          case .unchanged:
            refusals.append(
              .init(.init(code: "repair-selection", detail: "automatic evidence was unchanged"))
            )
          case .refused:
            refusals.append(
              .init(.init(code: "repair-selection", detail: "automatic evidence was refused"))
            )
          case .edits(let edits):
            guard edits.count == 1, case .rewrite = edits[0] else {
              refusals.append(
                .init(
                  .init(
                    code: "repair-selection",
                    detail: "automatic evidence was not one rewrite"
                  )
                )
              )
              continue
            }
            for edit in edits {
              let operation = try Self.stage(
                edit,
                root: subject.root,
                files: &staged,
                affected: &affected
              )
              operations.append(operation)
            }
          }
        }
      }
      for id in selectedEvidence.subtracting(observedEvidence).sorted(by: Self.ordered) {
        refusals.append(
          .init(
            .init(
              code: "repair-selection",
              detail: "automatic evidence is missing for \(id.rule.token) at \(id.file)"
            )
          )
        )
      }
      self.subject = subject
      self.binding = subject.binding
      self.profile = profile
      self.sources = sources
      self.files = staged.values.sorted(by: { $0.path < $1.path })
      self.operations = operations
      self.refusals = refusals
      self.engines = engines
      self.selectedEvidence = selectedEvidence
    }

    public func finish(remeasured: [Source.Measurement]) -> Plan {
      var refusals = self.refusals
      let repeated = Swift.Set(remeasured.map(\.engine))
      if repeated != engines || repeated.count != remeasured.count {
        refusals.append(.init(.init(code: "remeasurement-engines", detail: subject.identity)))
      }
      for measurement in remeasured {
        guard measurement.subject == subject else {
          refusals.append(.init(.init(code: "stale-subject", detail: measurement.subject.identity)))
          continue
        }
        guard measurement.repairs.filter({
          selectedEvidence.contains($0.id) && Self.actionable($0)
        }).isEmpty
        else {
          refusals.append(.init(.init(code: "non-idempotent", detail: measurement.engine.token)))
          continue
        }
        if measurement.suppressions.contains(where: { selectedEvidence.contains(Self.id($0)) }) {
          refusals.append(.init(.init(code: "suppression", detail: measurement.engine.token)))
          continue
        }
        let required = selectedEvidence.filter { $0.rule.engine == measurement.engine }
        if !required.isEmpty {
          let complete = required.allSatisfy { id in
            measurement.files.contains(id.file)
              && measurement.activeRules.contains(id.rule)
              && measurement.applicableRules.contains(id.rule)
              && measurement.observations.contains { observation in
                observation.file == id.file && observation.rule == id.rule
                  && observation.applicable && observation.coverage == .measured
              }
          }
          if !complete {
            refusals.append(
              .init(.init(code: "incomplete-remeasurement", detail: measurement.engine.token))
            )
            continue
          }
        }
        switch measurement.verdict {
        case .clean: break
        case .findings(let findings):
          if findings.contains(where: {
            selectedEvidence.contains(Self.id($0)) && $0.repair == .automatic
          }) {
            refusals.append(
              .init(.init(code: "postmeasurement-findings", detail: measurement.engine.token))
            )
          }
        case .unmeasured(let reasons): refusals.append(contentsOf: reasons.map(Refusal.init))
        case .notRequested:
          refusals.append(.init(.init(code: "not-requested", detail: measurement.engine.token)))
        }
      }
      let postconditions = files.map { file -> Postcondition in
        if let contents = file.contents {
          return .file(path: file.path, digest: Self.digest(contents))
        }
        return .absent(path: file.path)
      }
      return Plan(
        subject: binding,
        profile: profile,
        sources: sources,
        operations: operations,
        refusals: refusals,
        postconditions: postconditions
      )
    }

    private static func stage(
      _ edit: Source.Repair.Evidence.Edit,
      root: Swift.String,
      files: inout [Swift.String: Staged.File],
      affected: inout Swift.Set<Swift.String>
    ) throws(Source.Reason) -> Operation {
      switch edit {
      case .rewrite(let path, let contents):
        let path = try relative(path, root: root)
        try reserve(path, affected: &affected)
        guard let original = files[path]?.contents else {
          throw .init(code: "malformed-rewrite", detail: path)
        }
        let replacement = [UInt8](contents.utf8)
        files[path] = .init(path: path, contents: replacement)
        return .rewrite(path: path, expected: digest(original), replacement: replacement)
      case .create(let path, let contents):
        let path = try relative(path, root: root)
        try reserve(path, affected: &affected)
        guard files[path] == nil else { throw .init(code: "create-collision", detail: path) }
        let bytes = [UInt8](contents.utf8)
        files[path] = .init(path: path, contents: bytes)
        return .create(path: path, contents: bytes)
      case .move(let from, let to):
        let from = try relative(from, root: root)
        let to = try relative(to, root: root)
        try reserve(from, affected: &affected)
        try reserve(to, affected: &affected)
        guard let contents = files[from]?.contents else {
          throw .init(code: "move-source", detail: from)
        }
        guard files[to] == nil else { throw .init(code: "move-collision", detail: to) }
        files[from] = .init(path: from, contents: nil)
        files[to] = .init(path: to, contents: contents)
        return .move(from: from, to: to, expected: digest(contents))
      case .delete(let path):
        let path = try relative(path, root: root)
        try reserve(path, affected: &affected)
        guard let contents = files[path]?.contents else {
          throw .init(code: "delete-source", detail: path)
        }
        files[path] = .init(path: path, contents: nil)
        return .delete(path: path, expected: digest(contents))
      }
    }

    private static func reserve(
      _ path: Swift.String,
      affected: inout Swift.Set<Swift.String>
    ) throws(Source.Reason) {
      guard affected.insert(path).inserted else {
        throw .init(code: "overlapping-engine-conflict", detail: path)
      }
    }

    private static func relative(
      _ path: Swift.String,
      root: Swift.String
    ) throws(Source.Reason) -> Swift.String {
      let relative: Swift.String
      if path.hasPrefix("/") {
        let prefix = root.hasSuffix("/") ? root : root + "/"
        guard path.hasPrefix(prefix) else {
          throw .init(code: "path-escape", detail: path)
        }
        relative = Swift.String(path.dropFirst(prefix.count))
      } else {
        relative = path
      }
      guard !relative.isEmpty,
        !relative.hasPrefix("/"),
        !relative.split(separator: "/").contains("..")
      else { throw .init(code: "path-escape", detail: path) }
      return relative
    }

    private static func digest(_ contents: [UInt8]) -> Swift.String {
      FIPS_180_4.SHA256.digest(contents.map(Byte.init)).hex
    }

    private static func rank(_ engine: Source.Engine.ID) -> Swift.Int {
      switch engine.token {
      case "swift-linter": 0
      case "swiftlint": 1
      case "swift-format": 2
      default: 3
      }
    }

    private static func id(_ finding: Source.Finding) -> Source.Repair.Evidence.ID {
      .init(
        file: finding.diagnostic.location.filePath ?? finding.diagnostic.location.fileID,
        rule: finding.rule
      )
    }

    private static func actionable(_ evidence: Source.Repair.Evidence) -> Swift.Bool {
      switch evidence.disposition {
      case .edits, .refused: true
      case .unchanged: false
      }
    }

    private static func ordered(
      _ lhs: Source.Repair.Evidence.ID,
      _ rhs: Source.Repair.Evidence.ID
    ) -> Swift.Bool {
      (lhs.rule.engine.token, lhs.rule.token, lhs.file)
        < (rhs.rule.engine.token, rhs.rule.token, rhs.file)
    }
  }
}
