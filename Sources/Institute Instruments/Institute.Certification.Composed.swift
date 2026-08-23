public import Institute_Model
public import Institute_Build_Coordinator
public import Institute_Development
import File_System
import Git_Foundation
import Package_Manager
import JSON

extension Institute.Certification {
    /// Composed exact-S fleet evaluation: every package member is
    /// materialized as an isolated certifier-owned detached checkout of
    /// exactly its snapshot revision (`Institute.Checkout`) — developer
    /// worktrees can seed the object store but never contribute bytes —
    /// and every internal edge each member declares is redirected to that
    /// dependency's certifier-owned tree through one source-map
    /// transaction per member (`Institute.Development.VerificationPlan`),
    /// restored byte-for-byte afterward.
    public enum Composed {}
}

extension Institute.Certification.Composed {
    /// One composed evaluation's complete result: the obligation accounts,
    /// plus how many closure coverages failed or were unmeasurable.
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

    /// Evaluates every owed obligation against the composed exact-S
    /// materializations. The evaluation refuses before any member is
    /// evaluated unless every materialization verified, reporting every
    /// failed member, not just the first. Coverage is read from each
    /// member's own resolution with both `.localPath` and `.remoteExact`
    /// acceptable: under composition internal edges are file-system states
    /// local to S, and a remote-exact edge is also lawful; anything else
    /// fails per the instrument. Evidence lines (closure coverages and
    /// materialization receipts) go to `emit`, exactly as `certification
    /// run` prints them; diagnostics go to `diagnose`.
    public static func accounts(
        obligations: [Institute.Certification.Obligation],
        snapshot: Institute.Certification.Snapshot,
        root: Institute.Root,
        configuration: Institute.Configuration,
        platform: Institute.Certification.Platform,
        emit: (Swift.String) -> Swift.Void,
        diagnose: (Swift.String) -> Swift.Void
    ) throws(Institute.Error) -> Evaluation {
        let git = Git.Client()
        let coordinator = Institute.Build.Coordinator()
        let packages = Package.Manager()
        var repositories = [Swift.String: Institute.Repository]()
        for repository in configuration.repositories {
            repositories["\(repository.organization)/\(repository.name)"] = repository
        }

        // Exact-S by construction; every failure is collected so one
        // refusal names the whole repair.
        let certifier = File.Directory(
            File.Path(
                "\(root.hierarchy)/.certifier-exact/\(snapshot.digest.prefix(12))"
            )
        )
        if File.System.Stat.exists(at: certifier.path) {
            // Residue of an interrupted run of this same snapshot. The
            // namespace is certifier-owned scratch; a partially published
            // prior tree must not be trusted, so start clean.
            do throws(File.System.Delete.Error) {
                try certifier.delete.recursive()
            } catch {
                throw .filesystem(
                    "certification run --composed: cannot clear certifier scratch "
                        + "\(certifier): \(error)"
                )
            }
        }
        let checkout = Institute.Checkout(client: git)
        var skews = [Swift.String]()
        var directories = [Institute.Repository.Key: File.Directory]()
        var trees = [Institute.Repository.Key: Swift.String]()
        for member in snapshot.members.sorted(by: { $0.key.identity < $1.key.identity }) {
            guard case .package = member.kind else { continue }
            guard let repository = repositories[member.key.identity] else {
                skews.append("\(member.key.identity): no inventory repository record")
                continue
            }
            guard let revision = Git.Object.ID(rawValue: member.revision.sha) else {
                skews.append(
                    "\(member.key.identity): snapshot revision is not a Git object "
                        + "identifier: \(member.revision.sha)"
                )
                continue
            }
            // The developer materialization, when readable, seeds the
            // clone's object store so most members materialize without a
            // network fetch. Its absence is not a failure — the canonical
            // remote supplies the exact object instead.
            let objects: Swift.String?
            do throws(Institute.Error) {
                objects = try root.materialization(for: repository).description
            } catch {
                objects = nil
            }
            let destination = certifier[
                directory: File.Path.Component(
                    "\(member.key.owner)__\(member.key.name)"
                )
            ]
            let materialized: Institute.Checkout.Materialized
            do throws(Institute.Error) {
                materialized = try checkout.materialize(
                    url: repository.url,
                    objects: objects,
                    revision: revision,
                    to: destination
                )
            } catch {
                skews.append("\(member.key.identity): \(error)")
                continue
            }
            directories[member.key] = materialized.directory
            trees[member.key] = materialized.tree.rawValue
        }
        guard skews.isEmpty else {
            throw .configuration(
                "certification run --composed: exact-S materialization failed "
                    + "(\(skews.count) member(s)); refusing before any evaluation:\n"
                    + skews.joined(separator: "\n")
            )
        }

        // The source map: every materialized snapshot member redirects to
        // its exact certifier-owned tree, whether or not a given member
        // declares it — the plan applies only the assignments a manifest
        // declares. A governed repository outside the admitted population
        // is deliberately unmapped: a dependency on it stays remote and
        // the closure proof attributes the escape.
        var assignments = [Institute.Development.VerificationPlan.Assignment]()
        var members = [Swift.String: Institute.Repository.Key]()
        for member in snapshot.members.sorted(by: { $0.key.identity < $1.key.identity }) {
            guard
                let directory = directories[member.key],
                let repository = repositories[member.key.identity]
            else { continue }
            assignments.append(
                .init(
                    reference: repository.name,
                    url: repository.url,
                    path: directory.description
                )
            )
            members[repository.name] = member.key
        }

        var coverageFailures = 0
        var accounts = [Institute.Certification.Account]()
        var byMember = [Institute.Repository.Key: [Institute.Certification.Obligation]]()
        for obligation in obligations {
            byMember[obligation.key, default: []].append(obligation)
        }
        var seeds = [Swift.String]()
        var keys = [Swift.String: Institute.Repository.Key]()
        for (key, owed) in byMember.sorted(by: { $0.key.identity < $1.key.identity }) {
            guard snapshot[key] != nil else {
                for obligation in owed {
                    accounts.append(
                        .init(
                            obligation: obligation,
                            outcome: .failed(
                                diagnostic: "\(key.identity): not an admitted snapshot member"
                            )
                        )
                    )
                }
                continue
            }
            guard directories[key] != nil, let repository = repositories[key.identity] else {
                for obligation in owed {
                    accounts.append(
                        .init(
                            obligation: obligation,
                            outcome: .unmeasured(
                                reason: "\(key.identity): not a composable package member"
                            )
                        )
                    )
                }
                continue
            }
            seeds.append(repository.name)
            keys[repository.name] = key
        }

        let plan = Institute.Development.VerificationPlan(
            composition: .init(root: root, configuration: configuration),
            assignments: assignments
        )
        let results = try plan.run(seeds: seeds) {
            (seed: Swift.String) throws(Institute.Error) in
            guard
                let key = keys[seed],
                let member = snapshot[key],
                let directory = directories[key]
            else {
                return .failed("\(seed): not a prepared composed member")
            }
            var failures = 0
            for obligation in byMember[key] ?? [] {
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
                        at: directory.description,
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
                            outcome: .met(evidence: "composed@\(member.revision.sha):exit:0")
                        )
                    )
                } else {
                    let captured =
                        Swift.String(
                            decoding: (result.standardOutput ?? []) + (result.standardError ?? []),
                            as: Swift.UTF8.self
                        )
                    let lines = captured.split(separator: "\n")
                    let diagnostic =
                        lines.first { $0.contains(": error:") }.map(Swift.String.init)
                        ?? lines.last(where: { !$0.isEmpty }).map(Swift.String.init)
                        ?? "failed with no captured diagnostic"

                    accounts.append(
                        .init(
                            obligation: obligation,
                            outcome: .failed(diagnostic: "\(key.identity): \(diagnostic)")
                        )
                    )
                    failures += 1
                }
            }

            let resolved: Package.Resolution?
            do throws(Package.Manager.Error) {
                resolved = try packages.resolution(at: directory.description)
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
                            snapshot: snapshot,
                            accepting: [.localPath, .remoteExact]
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
                    "closure: \(key.identity): composed resolution unreadable — UNMEASURED\n"
                )
                coverageFailures += 1
            }
            return failures == 0
                ? .passed
                : .failed("\(key.identity): \(failures) obligation(s) failed")
        }

        // One evaluation-input receipt per evaluated member: the exact
        // revision and verified tree that were materialized, plus the
        // semantic transformation plan the source-map transaction actually
        // applied to that member's manifest. Emitted as evidence lines for
        // `certification assemble`, exactly like coverage.
        for result in results {
            guard
                let key = members[result.seed],
                let member = snapshot[key],
                let tree = trees[key]
            else { continue }
            var transformations = [Institute.Certification.Materialization.Transformation]()
            var lawful = true
            for reference in result.composed.sorted() {
                guard
                    let dependency = members[reference],
                    let target = snapshot[dependency]
                else {
                    diagnose(
                        "materialization: \(key.identity): composed dependency "
                            + "\(reference) is not an admitted snapshot member — "
                            + "receipt withheld\n"
                    )
                    lawful = false
                    break
                }
                do throws(Institute.Error) {
                    transformations.append(
                        try .init(
                            file: "Package.swift",
                            dependency: dependency.identity,
                            target: target.revision
                        )
                    )
                } catch {
                    diagnose(
                        "materialization: \(key.identity): \(error) — receipt withheld\n"
                    )
                    lawful = false
                    break
                }
            }
            guard lawful else { continue }
            do throws(Institute.Error) {
                let receipt = try Institute.Certification.Materialization(
                    key: key,
                    revision: member.revision,
                    tree: tree,
                    transformations: transformations
                )
                emit(receipt.json.serialize(sortKeys: true))
            } catch {
                diagnose(
                    "materialization: \(key.identity): receipt construction failed — "
                        + "\(error)\n"
                )
            }
        }
        return .init(accounts: accounts, coverageFailures: coverageFailures)
    }
}
