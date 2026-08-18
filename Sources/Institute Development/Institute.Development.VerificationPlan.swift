public import File_System
public import Institute_Model
public import Package_Manager
// `Package.Manifest` is an extension member declared in SPM_Standard; under
// MemberImportVisibility the re-export via Package_Manager does not surface it
// for nested-type naming, so import it directly.
public import SPM_Standard
private import Synchronization

extension Institute.Development {
    /// A serial per-seed verification plan over an ordered source-map
    /// transaction.
    ///
    /// For each explicit seed, in deterministic inventory-reference order,
    /// the plan derives the seed's dependency assignments from the canonical
    /// source map, captures the exact preimage of every file the mechanism
    /// changes, refuses to begin if a touched file is already in an
    /// unsupported dirty state, applies the full map atomically, invokes the
    /// package verification owner, restores exact bytes on success, typed
    /// error and cancellation alike, records the child verification result,
    /// and moves to the next seed only after complete restoration.
    ///
    /// The plan starts **one** package verification process at a time: seeds
    /// run strictly serially, and a second concurrent ``run(seeds:verify:)``
    /// in the same process is refused with a typed error.
    ///
    /// The verification owner is injected. The instrument layer above this
    /// module owns package verification and already depends on it, so the
    /// dependency cannot point the other way; the CLI wires the owner in.
    /// Nothing in this plan ever reads, writes or deletes `Package.resolved`
    /// — the only file it touches is each seed's `Package.swift`, and that
    /// only between preimage capture and byte-exact restoration.
    public struct VerificationPlan: Swift.Sendable {
        /// The composition environment resolving repositories, manifests and
        /// the ledger.
        public let composition: Institute.Composition

        /// The full source map's assignments: every repository the map
        /// redirects, whether or not a given seed declares it.
        public let assignments: [Assignment]

        public init(
            composition: Institute.Composition,
            assignments: [Assignment]
        ) {
            self.composition = composition
            self.assignments = assignments
        }
    }
}

extension Institute.Development.VerificationPlan {
    /// One source assignment derived from the canonical source map: an
    /// inventory reference, the source-control URL consumers declare it by,
    /// and the local checkout directory it redirects to.
    public struct Assignment: Swift.Equatable, Swift.Sendable {
        public let reference: Swift.String
        public let url: Swift.String
        public let path: Swift.String

        public init(
            reference: Swift.String,
            url: Swift.String,
            path: Swift.String
        ) {
            self.reference = reference
            self.url = url
            self.path = path
        }

        /// The assignment a normalized canonical source-map entry induces.
        public init(entry: Institute.Composition.SourceMap.Entry) {
            self.init(
                reference: entry.repository.name,
                url: entry.repository.url,
                path: entry.directory.description
            )
        }
    }
}

extension Institute.Development.VerificationPlan {
    /// The verification owner's verdict for one seed.
    public enum Verification: Swift.Equatable, Swift.Sendable {
        case passed

        case failed(Swift.String)
    }

    /// One recorded child verification result: the seed, its verdict, and
    /// the references the transaction redirected while the owner ran.
    public struct Result: Swift.Equatable, Swift.Sendable {
        public let seed: Swift.String
        public let verification: Verification
        public let composed: [Swift.String]

        public init(
            seed: Swift.String,
            verification: Verification,
            composed: [Swift.String]
        ) {
            self.seed = seed
            self.verification = verification
            self.composed = composed
        }
    }
}

extension Institute.Development.VerificationPlan {
    /// One prepared source-map transaction over a single consumer manifest:
    /// the exact preimage, the fully applied rewrite, and the per-assignment
    /// clause rewrites — computed entirely in memory, so refusal happens
    /// **before** any mutation.
    ///
    /// The applied source is written in **one** atomic write, so there is no
    /// partially applied on-disk state within a transaction; restoration is
    /// one atomic write of the captured preimage.
    public struct Transaction: Swift.Sendable {
        /// One applied clause rewrite: the reference redirected, the exact
        /// declared clause captured verbatim, and the exact planned clause
        /// written in its place.
        public struct Rewrite: Swift.Equatable, Swift.Sendable {
            public let reference: Swift.String
            public let declared: Swift.String
            public let planned: Swift.String

            public init(
                reference: Swift.String,
                declared: Swift.String,
                planned: Swift.String
            ) {
                self.reference = reference
                self.declared = declared
                self.planned = planned
            }
        }

        public let consumer: Swift.String
        public let manifest: File
        public let preimage: Swift.String
        public let applied: Swift.String
        public let rewrites: [Rewrite]
    }
}

extension Institute.Development.VerificationPlan.Transaction {
    /// Prepares the transaction redirecting every assignment `consumer`
    /// declares by URL, in sorted reference order, without touching disk.
    ///
    /// Refusal — always before any mutation, since nothing has been written
    /// yet — covers the unsupported dirty states: an assignment already
    /// composed pairwise in the ledger, and a manifest already carrying an
    /// assignment's planned path clause without a ledger record. An
    /// assignment the consumer does not declare by URL contributes nothing:
    /// forward-closure map entries are redirect targets, never automatic
    /// verification subjects.
    public static func begin(
        consumer: Swift.String,
        manifest: File,
        source: Swift.String,
        assignments: [Institute.Development.VerificationPlan.Assignment],
        ledger: Institute.Composition.State
    ) throws(Institute.Error) -> Self {
        var current = source
        var rewrites = [Rewrite]()

        let applicable =
            assignments
            .filter { $0.reference != consumer }
            .sorted { $0.reference < $1.reference }
        for assignment in applicable {
            guard ledger.record(consumer: consumer, dependency: assignment.reference) == nil
            else {
                throw .composition(
                    """
                    \(consumer) already composes \(assignment.reference) pairwise; restore it \
                    before running a source-map transaction over it
                    """
                )
            }

            let planned = ".package(path: \"\(assignment.path)\")"
            guard !current.contains(planned) else {
                throw .composition(
                    """
                    \(consumer)'s manifest already carries the composed clause for \
                    \(assignment.reference) without a ledger record — unsupported dirty state; \
                    refusing before any mutation
                    """
                )
            }

            let identity = Package.Manifest.Clause.identity(ofURL: assignment.url)
            guard Package.Manifest.Clause.url(identity: identity, in: current) != nil else {
                continue
            }

            do throws(Package.Manifest.Redirection.Error) {
                let rewrite = try Package.Manifest.Redirection.redirect(
                    current,
                    dependency: assignment.url,
                    to: assignment.path
                )
                current = rewrite.source
                rewrites.append(
                    .init(
                        reference: assignment.reference,
                        declared: rewrite.declared,
                        planned: rewrite.planned
                    )
                )
            } catch {
                throw .composition(
                    "cannot redirect \(assignment.reference) in \(consumer): \(error)"
                )
            }
        }

        return .init(
            consumer: consumer,
            manifest: manifest,
            preimage: source,
            applied: current,
            rewrites: rewrites
        )
    }

    /// Applies the full map in one atomic write.
    public func apply(through composition: Institute.Composition) throws(Institute.Error) {
        try composition.write(applied, to: manifest)
    }

    /// Restores the exact preimage bytes in one atomic write.
    public func restore(through composition: Institute.Composition) throws(Institute.Error) {
        try composition.write(preimage, to: manifest)
    }

    /// Restores after `failure`, folding a restoration failure into one
    /// combined error so neither outcome is silently lost.
    public func restore(
        through composition: Institute.Composition,
        after failure: Institute.Error
    ) throws(Institute.Error) {
        do throws(Institute.Error) {
            try restore(through: composition)
        } catch {
            throw .composition(
                """
                \(failure); restoring \(manifest) ALSO failed: \(error) — the manifest may still \
                carry composed clauses
                """
            )
        }
    }
}

extension Institute.Development.VerificationPlan {
    /// The in-process occupancy claim enforcing one running plan — and so
    /// one package verification process — at a time.
    private static let running = Mutex<Swift.Bool>(false)

    /// Runs the plan over `seeds` in deterministic inventory-reference
    /// order, invoking `verify` for each seed while its transaction is
    /// applied, and restoring exact bytes before recording the child result
    /// and moving on.
    public func run(
        seeds: [Swift.String],
        verify: (Swift.String) throws(Institute.Error) -> Verification
    ) throws(Institute.Error) -> [Result] {
        let claimed = Self.running.withLock { running in
            guard !running else { return false }
            running = true
            return true
        }
        guard claimed else {
            throw .composition(
                "a verification plan is already running; one package verification at a time"
            )
        }
        defer {
            Self.running.withLock { running in running = false }
        }

        var results = [Result]()
        for seed in Swift.Set(seeds).sorted() {
            guard !Task.isCancelled else {
                throw .composition(
                    "verification plan cancelled before \(seed); no transaction was applied"
                )
            }

            let repository = try composition.require(seed)
            let manifest = try composition.manifestFile(for: repository)
            let source = try composition.read(manifest)
            let ledger = try Institute.Composition.State.load(at: composition.root.checkout)
            let transaction = try Transaction.begin(
                consumer: seed,
                manifest: manifest,
                source: source,
                assignments: assignments,
                ledger: ledger
            )

            try transaction.apply(through: composition)

            let verification: Verification
            do throws(Institute.Error) {
                verification = try verify(seed)
            } catch {
                try transaction.restore(through: composition, after: error)
                throw error
            }

            try transaction.restore(through: composition)

            guard !Task.isCancelled else {
                throw .composition(
                    "verification plan cancelled after \(seed); every preimage was restored"
                )
            }

            results.append(
                .init(
                    seed: seed,
                    verification: verification,
                    composed: transaction.rewrites.map(\.reference)
                )
            )
        }
        return results
    }
}
