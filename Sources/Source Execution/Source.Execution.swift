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
            let governed = subject.governed
            for engine in profile.engines {
                if let selected, !selected.contains(engine.id) { continue }
                let artifacts = governed.artifacts.filter { engine.artifactKinds.contains($0.kind) }
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
                let measurement = await driver.measure(governed, engine)
                let controls = await self.controls(of: subject, engine: engine, driver: driver)
                measurements.append(
                    .init(
                        engine: measurement.engine,
                        subject: subject,
                        activeRules: measurement.activeRules,
                        applicableRules: measurement.applicableRules,
                        files: measurement.files,
                        observations: measurement.observations,
                        suppressions: measurement.suppressions,
                        repairs: measurement.repairs,
                        controls: measurement.controls + controls,
                        verdict: measurement.verdict
                    )
                )
            }
            return measurements.sorted { $0.engine.token < $1.engine.token }
        }

        /// Measures each control artifact whose predicate `engine` owns on its
        /// own, and compares the predicate's findings in it with the declared
        /// expectation. The artifact's other findings are not evidence of
        /// anything and are dropped; it is not governed source.
        private func controls(
            of subject: Subject,
            engine: Profile.Engine,
            driver: Engine.Driver
        ) async -> [Rule.Control.Evidence] {
            let declared = subject.artifacts.compactMap {
                artifact -> (artifact: Artifact, control: Artifact.Purpose.Control)? in
                guard case .control(let control) = artifact.purpose,
                    control.predicate.engine == engine.id,
                    engine.artifactKinds.contains(artifact.kind)
                else { return nil }
                return (artifact, control)
            }
            guard !declared.isEmpty else { return [] }
            let probe = await driver.measure(
                Subject(identity: subject.identity, root: subject.root, artifacts: declared.map(\.artifact)),
                engine
            )
            let prefix = subject.root.hasSuffix("/") ? subject.root : subject.root + "/"
            return declared.map { declaration in
                let control = declaration.control
                let expected: Swift.Int
                switch control.expectation {
                case .clean: expected = 0
                case .findings(let count): expected = count
                }
                let findings: [Finding]
                switch probe.verdict {
                case .clean:
                    findings = []
                case .findings(let reported):
                    findings = reported
                case .unmeasured(let reasons):
                    return .init(
                        identity: control.identity,
                        rule: control.predicate,
                        expectation: control.expectation,
                        actualFindings: 0,
                        verdict: .unmeasured(reasons)
                    )
                case .notRequested:
                    return .init(
                        identity: control.identity,
                        rule: control.predicate,
                        expectation: control.expectation,
                        actualFindings: 0,
                        verdict: .unmeasured([.init(code: "control-not-requested", detail: control.identity)])
                    )
                }
                let actual = findings.count {
                    $0.rule == control.predicate
                        && $0.diagnostic.location.filePath == prefix + declaration.artifact.path
                }
                return .init(
                    identity: control.identity,
                    rule: control.predicate,
                    expectation: control.expectation,
                    actualFindings: actual,
                    verdict: actual == expected
                        ? .clean
                        : .findings([
                            .init(
                                code: "control-failed",
                                detail: "\(control.identity): expected \(expected) \(control.predicate.token) findings, found \(actual)"
                            )
                        ])
                )
            }
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
                let proposal = await driver.repair(subject.governed, engine)
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
