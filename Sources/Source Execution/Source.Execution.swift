extension Source {
  public struct Execution: Sendable {
    private let drivers: [Engine.ID: Engine.Driver]

    public init(drivers: [Engine.Driver]) throws(Error) {
      var registered: [Engine.ID: Engine.Driver] = [:]
      for driver in drivers {
        guard registered[driver.id] == nil else { throw .duplicate(driver.id) }
        registered[driver.id] = driver
      }
      self.drivers = registered
    }

    public func measure(
      _ subject: Subject,
      profile: Profile,
      engines selected: Set<Engine.ID>? = nil
    ) async -> [Measurement] {
      var measurements: [Measurement] = []
      for engine in profile.engines {
        if let selected, !selected.contains(engine.id) { continue }
        let artifacts = subject.artifacts.filter { engine.artifactKinds.contains($0.kind) }
        guard let driver = drivers[engine.id] else {
          measurements.append(
            .init(
              engine: engine.id,
              subject: subject,
              activeRules: engine.rules,
              applicableRules: [],
              files: artifacts.map(\.path),
              verdict: .unmeasured([
                .init(
                  code: "missing-driver",
                  detail: "no driver registered for \(engine.id.token)"
                )
              ])
            )
          )
          continue
        }
        measurements.append(await driver.measure(subject, engine))
      }
      return measurements.sorted { $0.engine.token < $1.engine.token }
    }

    public func plan(
      _ subject: Subject,
      profile: Profile,
      engines selected: Set<Engine.ID>? = nil
    ) async -> [Measurement] {
      let measurements = await measure(subject, profile: profile, engines: selected)
      var planned: [Measurement] = []
      for measurement in measurements {
        guard case .findings = measurement.verdict,
          measurement.repairs.isEmpty,
          let driver = drivers[measurement.engine],
          let engine = profile.engines.first(where: { $0.id == measurement.engine }),
          engine.rules.count == 1,
          let rule = engine.rules.first
        else {
          planned.append(measurement)
          continue
        }
        let proposal = await driver.repair(subject, engine)
        var repairs: [Repair.Evidence] = proposal.edits.map { edit in
          let disposition: Repair.Evidence.Disposition
          if subject.artifacts.contains(where: {
            let prefix = subject.root.hasSuffix("/") ? subject.root : subject.root + "/"
            return edit.path.hasPrefix(prefix)
              && $0.path == Swift.String(edit.path.dropFirst(prefix.count))
              && $0.digest.hex == edit.expected
          }) {
            disposition = .edits([
              .rewrite(
                path: edit.path,
                contents: Swift.String(decoding: edit.replacement, as: UTF8.self)
              )
            ])
          } else {
            disposition = .refused(.init(code: "stale-repair-evidence", detail: edit.path))
          }
          return .init(file: edit.path, rule: rule, disposition: disposition)
        }
        repairs.append(
          contentsOf: proposal.refusals.map {
            .init(file: subject.root, rule: rule, disposition: .refused($0))
          }
        )
        let repairable = Set(
          repairs.compactMap { evidence -> Swift.String? in
            if case .edits = evidence.disposition { return evidence.file }
            return nil
          }
        )
        let verdict: Measurement.Verdict
        if case .findings(let findings) = measurement.verdict {
          verdict = .findings(
            findings.map { finding in
              guard let file = finding.diagnostic.location.filePath,
                repairable.contains(file)
              else { return finding }
              return .init(
                rule: finding.rule,
                diagnostic: finding.diagnostic,
                repair: .automatic
              )
            }
          )
        } else {
          verdict = measurement.verdict
        }
        planned.append(
          .init(
            engine: measurement.engine,
            subject: measurement.subject,
            activeRules: measurement.activeRules,
            applicableRules: measurement.applicableRules,
            files: measurement.files,
            observations: measurement.observations,
            suppressions: measurement.suppressions,
            repairs: repairs,
            controls: measurement.controls,
            verdict: verdict
          )
        )
      }
      return planned.sorted { $0.engine.token < $1.engine.token }
    }
  }
}
