public import Institute_Model
public import Institute_Build_Coordinator
import File_System
import Git_Foundation
import Package_Manager
import JSON

extension Institute.Certification {
    /// Ephemeral exact-revision fleet evaluation: each member is cloned
    /// from its local materialization, proven to stand at the snapshot
    /// revision, fresh-repinned so internal edges resolve to current tips
    /// (= the snapshot at freeze time), executed, read for closure
    /// coverage, and deleted. No shared tree is mutated.
    public enum Ephemeral {}
}

extension Institute.Certification.Ephemeral {
    /// One ephemeral evaluation's complete result: the obligation
    /// accounts, plus how many closure coverages failed or were
    /// unmeasurable.
    public struct Evaluation: Sendable {
        public let accounts: [Institute.Certification.Account]
        public let coverageFailures: Swift.Int

        public init(
            accounts: [Institute.Certification.Account],
            coverageFailures: Swift.Int
        ) {
            self.accounts = accounts
            self.coverageFailures = coverageFailures
        }
    }

    /// Removes an ephemeral evaluation directory. A failed removal is
    /// surfaced through `diagnose`, never swallowed: leftover scratch is a
    /// disk-space defect, not an evaluation defect, so it must not fail an
    /// account.
    static func delete(
        at destination: Swift.String,
        diagnose: (Swift.String) -> Swift.Void
    ) {
        let path: File.Path
        do throws(File.Path.Error) {
            path = try File.Path(destination)
        } catch {
            return
        }
        do throws(File.System.Delete.Error) {
            try File.System.Delete.delete(at: path, recursive: true)
        } catch {
            diagnose("ephemeral: could not remove \(destination): \(error)\n")
        }
    }

    /// Evaluates every owed obligation against ephemeral exact-revision
    /// clones. Evidence lines (closure coverages) go to `emit`, exactly as
    /// `certification run` prints them; diagnostics go to `diagnose`.
    public static func accounts(
        obligations: [Institute.Certification.Obligation],
        snapshot: Institute.Certification.Snapshot,
        root: Institute.Root,
        configuration: Institute.Configuration,
        platform: Institute.Certification.Platform,
        emit: (Swift.String) -> Swift.Void,
        diagnose: (Swift.String) -> Swift.Void
    ) -> Evaluation {
        let git = Git.Client()
        let coordinator = Institute.Build.Coordinator()
        let packages = Package.Manager()
        var repositories = [Swift.String: Institute.Repository]()
        for repository in configuration.repositories {
            repositories["\(repository.organization)/\(repository.name)"] = repository
        }
        let scratch = "\(root.hierarchy)/.certifier-ephemeral"

        var coverageFailures = 0
        var accounts = [Institute.Certification.Account]()
        var byMember = [Institute.Repository.Key: [Institute.Certification.Obligation]]()
        for obligation in obligations {
            byMember[obligation.key, default: []].append(obligation)
        }

        for (key, owed) in byMember.sorted(by: { $0.key.identity < $1.key.identity }) {
            func account(_ outcome: Institute.Certification.Account.Outcome) {
                for obligation in owed {
                    accounts.append(.init(obligation: obligation, outcome: outcome))
                }
            }
            guard let member = snapshot[key] else {
                account(.failed(diagnostic: "\(key.identity): not an admitted snapshot member"))
                continue
            }
            guard let repository = repositories[key.identity] else {
                account(.failed(diagnostic: "\(key.identity): no inventory repository record"))
                continue
            }
            let source: File.Directory
            do throws(Institute.Error) {
                source = try root.materialization(for: repository)
            } catch {
                account(.unmeasured(reason: "\(key.identity): no readable materialization"))
                continue
            }
            let destination = "\(scratch)/\(repository.organization)__\(repository.name)"
            Self.delete(at: destination, diagnose: diagnose)
            do {
                try git.clone(source.description, branch: "main", to: destination)
            } catch {
                account(.unmeasured(reason: "\(key.identity): ephemeral clone failed: \(error)"))
                continue
            }
            defer { Self.delete(at: destination, diagnose: diagnose) }
            let head: Git.Object.ID
            do throws(Git.Client.Error) {
                head = try git.head("HEAD", at: destination)
            } catch {
                account(
                    .failed(
                        diagnostic: "\(key.identity): ephemeral head unreadable: \(error)"
                    )
                )
                continue
            }
            guard head.rawValue == member.revision.sha else {
                account(
                    .failed(
                        diagnostic: "\(key.identity): ephemeral clone is not the snapshot "
                            + "revision \(member.revision.sha)"
                    )
                )
                continue
            }
            // Re-pin the clone's committed Package.resolved to current
            // branch tips (= the snapshot at freeze time). Without this the
            // clone compiles whatever the member last committed — the exact
            // stale-pin class law 2 refuses.
            do {
                _ = try coordinator.run(
                    .update,
                    at: destination,
                    fresh: false,
                    arguments: [],
                    capturingDiagnostics: true
                )
            } catch {
                account(.unmeasured(reason: "\(key.identity): ephemeral update failed: \(error)"))
                continue
            }

            for obligation in owed {
                guard obligation.platform == platform else {
                    accounts.append(
                        .init(
                            obligation: obligation,
                            outcome: .unmeasured(
                                reason: "owed on \(obligation.platform.rawValue), this "
                                    + "execution measures \(platform.rawValue)"
                            )
                        )
                    )
                    continue
                }
                let action: Institute.Build.Action? =
                    switch obligation.kind {
                    case .build: .build
                    case .test: .test
                    case .lint, .format: nil
                    }
                guard let action else {
                    accounts.append(
                        .init(
                            obligation: obligation,
                            outcome: .unmeasured(
                                reason: "quality obligations are executed by the quality "
                                    + "instruments"
                            )
                        )
                    )
                    continue
                }
                let result: Institute.Build.Coordinator.Result
                do {
                    result = try coordinator.run(
                        action,
                        at: destination,
                        fresh: false,
                        arguments: [],
                        capturingDiagnostics: true
                    )
                } catch {
                    accounts.append(
                        .init(
                            obligation: obligation,
                            outcome: .unmeasured(reason: "coordinator error: \(error)")
                        )
                    )
                    continue
                }
                if result.exitCode == 0 {
                    accounts.append(
                        .init(
                            obligation: obligation,
                            outcome: .met(evidence: "ephemeral@\(member.revision.sha):exit:0")
                        )
                    )
                } else {
                    let captured =
                        Swift.String(
                            decoding: (result.standardOutput ?? []) + (result.standardError ?? []),
                            as: Swift.UTF8.self
                        )
                    let lines = captured.split(separator: "\n")
                    let firstError: Swift.String? =
                        lines.first { $0.contains(": error:") }.map(Swift.String.init)
                    let lastLine: Swift.String? =
                        lines.last(where: { !$0.isEmpty }).map(Swift.String.init)
                    let diagnostic: Swift.String =
                        firstError ?? lastLine ?? "failed with no captured diagnostic"

                    accounts.append(
                        .init(
                            obligation: obligation,
                            outcome: .failed(diagnostic: "\(key.identity): \(diagnostic)")
                        )
                    )
                }
            }

            let resolved: Package.Resolution?
            do throws(Package.Manager.Error) {
                resolved = try packages.resolution(at: destination)
            } catch {
                resolved = nil
            }
            if let resolution = resolved {
                do throws(Institute.Error) {
                    let coverage = try Institute.Certification.Closure.Coverage(
                        consumer: key,
                        proofs: Institute.Certification.Closure.proofs(
                            consumer: key,
                            resolution: resolution,
                            snapshot: snapshot
                        )
                    )
                    emit(coverage.json.serialize(sortKeys: true))
                    if !coverage.passes { coverageFailures += 1 }
                } catch {
                    diagnose(
                        "closure: \(key.identity): coverage refused — \(error) — UNMEASURED\n"
                    )
                    coverageFailures += 1
                }
            } else {
                diagnose(
                    "closure: \(key.identity): ephemeral resolution unreadable — UNMEASURED\n"
                )
                coverageFailures += 1
            }
        }
        return .init(accounts: accounts, coverageFailures: coverageFailures)
    }
}
