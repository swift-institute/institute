public import Build_Coordinator
public import File_System
public import Git_Foundation
public import Institute_Model

extension Institute.Certification {
    /// Executes obligations and records one ``Account`` per obligation —
    /// the law-3 instrument: package builds and package-owned tests are
    /// invoked and accounted individually, never inferred from a composed
    /// build's exit code.
    ///
    /// Scope honesty: one execution covers exactly one platform — the one
    /// it runs on. Every obligation owed on another platform is returned
    /// `unmeasured` with the platform named, so a single-host run can
    /// never masquerade as the whole platform contract; hosted legs cover
    /// the rest and their accounts merge into the certificate.
    ///
    /// Before executing a member, the instrument proves the materialized
    /// checkout is at exactly the snapshot member's revision. A mismatch
    /// is a failed account, not a warning: executing the wrong source
    /// would attribute evidence to a revision that was never measured.
    public struct Execution: Sendable {
        public let root: Institute.Root
        public let configuration: Institute.Configuration
        public let platform: Platform

        public let head:
            @Sendable (Institute.Root, Institute.Repository) throws(Institute.Error) ->
                Revision

        public let run:
            @Sendable (Obligation.Kind, File.Directory) -> Account.Outcome

        public init(
            root: Institute.Root,
            configuration: Institute.Configuration,
            platform: Platform,
            coordinator: Build.Coordinator = .init(),
            git: Git.Client = .init(),
            head: (
                @Sendable (Institute.Root, Institute.Repository) throws(Institute.Error) ->
                    Revision
            )? = nil,
            run: (@Sendable (Obligation.Kind, File.Directory) -> Account.Outcome)? = nil
        ) {
            self.root = root
            self.configuration = configuration
            self.platform = platform
            if let head {
                self.head = head
            } else {
                self.head = { root, repository throws(Institute.Error) in
                    try Derivation.materializedHead(
                        git: git,
                        root: root,
                        repository: repository
                    )
                }
            }
            if let run {
                self.run = run
            } else {
                self.run = { kind, directory in
                    Self.coordinated(
                        coordinator: coordinator,
                        kind: kind,
                        directory: directory
                    )
                }
            }
        }

        private static func coordinated(
            coordinator: Build.Coordinator,
            kind: Obligation.Kind,
            directory: File.Directory
        ) -> Account.Outcome {
            let action: Build.Action =
                switch kind {
                case .build: .build
                case .test: .test
                }
            let result: Build.Coordinator.Result
            do throws(Build.Error) {
                result = try coordinator.run(
                    action,
                    at: directory.description,
                    fresh: false,
                    arguments: [],
                    capturingDiagnostics: true
                )
            } catch {
                return .unmeasured(reason: "coordinator error: \(error)")
            }
            guard result.exitCode == 0 else {
                let diagnostic = Institute.Coherence.firstDiagnostic(
                    standardOutput: result.standardOutput ?? [],
                    standardError: result.standardError ?? []
                )
                return .failed(diagnostic: diagnostic)
            }
            return .met(evidence: "exit:0")
        }
    }
}

extension Institute.Certification.Execution {
    /// Execute every obligation this run's platform can measure, and
    /// account the rest `unmeasured` with the owed platform named.
    public func accounts(
        for obligations: [Institute.Certification.Obligation],
        in snapshot: Institute.Certification.Snapshot
    ) -> [Institute.Certification.Account] {
        var repositories = [Swift.String: Institute.Repository]()
        for repository in configuration.repositories {
            repositories["\(repository.organization)/\(repository.name)"] = repository
        }

        return obligations.map { obligation in
            guard obligation.platform == platform else {
                return .init(
                    obligation: obligation,
                    outcome: .unmeasured(
                        reason: "owed on \(obligation.platform.rawValue), "
                            + "this execution measures \(platform.rawValue)"
                    )
                )
            }
            guard let member = snapshot[obligation.key] else {
                return .init(
                    obligation: obligation,
                    outcome: .failed(
                        diagnostic: "\(obligation.key.identity): not an admitted snapshot member"
                    )
                )
            }
            guard let repository = repositories[obligation.key.identity] else {
                return .init(
                    obligation: obligation,
                    outcome: .failed(
                        diagnostic: "\(obligation.key.identity): no inventory repository record"
                    )
                )
            }

            let directory: File.Directory
            do throws(Institute.Error) {
                directory = try root.materialization(for: repository)
            } catch {
                return .init(
                    obligation: obligation,
                    outcome: .unmeasured(
                        reason: "\(obligation.key.identity): no readable materialization"
                    )
                )
            }

            let materialized: Institute.Certification.Revision
            do throws(Institute.Error) {
                materialized = try head(root, repository)
            } catch {
                return .init(
                    obligation: obligation,
                    outcome: .unmeasured(
                        reason: "\(obligation.key.identity): head of main is unreadable"
                    )
                )
            }
            guard materialized == member.revision else {
                return .init(
                    obligation: obligation,
                    outcome: .failed(
                        diagnostic: "\(obligation.key.identity): materialized "
                            + "\(materialized.sha) is not the snapshot member "
                            + member.revision.sha
                    )
                )
            }

            return .init(obligation: obligation, outcome: run(obligation.kind, directory))
        }
    }
}
