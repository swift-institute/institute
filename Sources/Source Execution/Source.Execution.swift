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
                let artifacts = subject.governed.artifacts.filter { engine.artifactKinds.contains($0.kind) }
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
                measurements.append(Self.split(await driver.measure(subject, engine), of: subject, engine: engine))
            }
            return measurements.sorted { $0.engine.token < $1.engine.token }
        }

        /// Separates an engine's measurement of the whole subject into the
        /// governed measurement and the evidence of the control artifacts.
        ///
        /// Engines measure the subject as one tree — swift-linter enumerates
        /// the package itself and refuses a partial file set — so controls are
        /// split out of the result rather than out of the input. Everything
        /// reported in a control artifact leaves the governed measurement; the
        /// control's predicate findings there, if this engine owns the
        /// predicate, are compared with the declared expectation. Its other
        /// findings are evidence of nothing and are dropped.
        private static func split(
            _ measurement: Measurement,
            of subject: Subject,
            engine: Profile.Engine
        ) -> Measurement {
            let prefix = subject.root.hasSuffix("/") ? subject.root : subject.root + "/"
            let declared = subject.artifacts.compactMap {
                artifact -> (path: Swift.String, control: Artifact.Purpose.Control)? in
                guard case .control(let control) = artifact.purpose else { return nil }
                return (prefix + artifact.path, control)
            }
            guard !declared.isEmpty else { return measurement }
            let controlFiles = Swift.Set(declared.map(\.path))
            let governed = { (file: Swift.String?) in !controlFiles.contains(file ?? "") }

            let observations = measurement.observations.filter { governed($0.file) }
            let applicableRules =
                measurement.observations.isEmpty
                ? measurement.applicableRules
                : measurement.applicableRules.filter { rule in
                    observations.contains { $0.rule == rule && $0.applicable }
                }
            let verdict: Measurement.Verdict
            let reported: [Finding]?
            switch measurement.verdict {
            case .findings(let findings):
                reported = findings
                let kept = findings.filter { governed($0.diagnostic.location.filePath) }
                verdict = kept.isEmpty ? .clean : .findings(kept)
            case .clean:
                reported = []
                verdict = .clean
            case .unmeasured, .notRequested:
                reported = nil
                verdict = measurement.verdict
            }

            let evidence: [Rule.Control.Evidence] = declared.filter {
                $0.control.predicate.engine == engine.id
            }.map { declaration in
                let control = declaration.control
                guard let reported else {
                    let reasons: [Reason]
                    if case .unmeasured(let unmeasured) = measurement.verdict {
                        reasons = unmeasured
                    } else {
                        reasons = [.init(code: "control-not-requested", detail: control.identity)]
                    }
                    return .init(
                        identity: control.identity,
                        rule: control.predicate,
                        expectation: control.expectation,
                        actualFindings: 0,
                        verdict: .unmeasured(reasons)
                    )
                }
                let expected: Swift.Int
                switch control.expectation {
                case .clean: expected = 0
                case .findings(let count): expected = count
                }
                let actual = reported.count {
                    $0.rule == control.predicate && $0.diagnostic.location.filePath == declaration.path
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

            return .init(
                engine: measurement.engine,
                subject: measurement.subject,
                activeRules: measurement.activeRules,
                applicableRules: applicableRules,
                files: measurement.files.filter { governed($0) },
                observations: observations,
                suppressions: measurement.suppressions.filter { governed($0.diagnostic.location.filePath) },
                repairs: measurement.repairs.filter { governed($0.file) },
                controls: measurement.controls + evidence,
                verdict: verdict
            )
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
                let governedPaths = Swift.Set(subject.governed.artifacts.map(\.path))
                var repairs: [Repair.Evidence] = proposal.edits.filter { edit in
                    let prefix = subject.root.hasSuffix("/") ? subject.root : subject.root + "/"
                    return !edit.path.hasPrefix(prefix)
                        || governedPaths.contains(Swift.String(edit.path.dropFirst(prefix.count)))
                }.map { edit in
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
