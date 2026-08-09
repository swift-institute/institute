public import Async_Fanout
public import File_System
public import Git_Foundation
public import Institute_Development
public import Institute_Model

extension Institute.Lint {
  /// The whole-ecosystem mode.
  ///
  /// Enumerates from `Institute.json` — never by walking the tree.
  /// A tree walk carries its own layout assumptions and fails toward
  /// clean-looking empties, which is the failure this capability
  /// exists to make impossible.
  ///
  /// The sweep is not a second implementation of linting. It resolves
  /// the installation once and then calls the same
  /// ``Institute/Lint/measure(_:using:default:)`` the single-package
  /// mode calls, so a package's verdict cannot depend on which entry
  /// point asked for it. That extends to the default rule set: the two
  /// modes reach the same ``Institute/Lint/Bundle`` by different
  /// routes — the inventory's layer here, the materialized path there
  /// — and ``Institute/Layout`` makes those routes agree.
  public struct Sweep: Sendable {
    public let lint: Institute.Lint

    /// The checkout whose inventory defines the population, and
    /// whose hierarchy the packages materialize under.
    public let root: Institute.Root

    /// The inventory, verbatim from `Institute.json`.
    public let repositories: [Institute.Repository]

    public let git: Git.Client

    /// How many packages are linted at once.
    ///
    /// Defaults to the online processor count. The engine's fast
    /// path is CPU-bound and single-threaded per package, so
    /// parallelism across packages is where the time goes.
    public let jobs: Swift.Int

    /// The online processor count.
    ///
    /// Read from the machine rather than fixed, so the sweep neither
    /// under-uses a large host nor oversubscribes a small one.
    public static var processors: Swift.Int {
      Async.Fanout.processors
    }

    public init(
      lint: Institute.Lint,
      root: Institute.Root,
      repositories: [Institute.Repository],
      git: Git.Client = .init(),
      jobs: Swift.Int? = nil
    ) {
      self.lint = lint
      self.root = root
      self.repositories = repositories
      self.git = git
      self.jobs = Swift.max(1, jobs ?? Self.processors)
    }
  }
}

extension Institute.Lint.Sweep {
  /// Which packages a sweep covers.
  public enum Scope: Equatable, Sendable {
    /// Every materialized package in the inventory.
    case all

    /// Only packages with local work: an unclean working tree, or
    /// commits not yet in the tracked upstream.
    ///
    /// Defined per repository rather than against one global ref,
    /// because the 441 packages are independent repositories with
    /// independent histories — a single shared ref has no meaning
    /// across them. A repository whose state cannot be read is
    /// **included**, never skipped: a scope filter that silently
    /// drops what it could not classify is the narrowing this
    /// capability is built to refuse.
    case changed
  }
}

extension Institute.Lint.Sweep {
  /// Lints the ecosystem and returns the aggregate.
  ///
  /// The empty-population guard is the sweep's own version of the
  /// per-package UNMEASURED rule, and it exists because this exact
  /// failure has happened in this fleet: a validator run from the
  /// wrong root scanned nothing and reported green. A sweep that
  /// enumerated an inventory and then found nothing on disk has not
  /// established that the ecosystem is clean; it has established that
  /// it is looking in the wrong place.
  public func run(
    scope: Scope = .all,
    fix: Institute.Lint.Fix? = nil
  ) async throws(Institute.Error) -> Institute.Lint.Report {
    try await run(scope: scope, fix: fix, format: .text)
  }

  /// Runs the complete inventory in structured-evidence mode and composes
  /// the authoritative residual ledger.
  public func ledger(
    dispositions: [Institute.Lint.Ledger.Disposition] = [],
    verifications: [Institute.Lint.Ledger.Verification] = []
  ) async throws(Institute.Error) -> Institute.Lint.Ledger.Report {
    let report = try await run(scope: .all, fix: nil, format: .sarif)
    return try .init(
      repositories: repositories,
      report: report,
      dispositions: dispositions,
      verifications: verifications
    )
  }

  private func run(
    scope: Scope,
    fix: Institute.Lint.Fix?,
    format: Institute.Lint.Format
  ) async throws(Institute.Error) -> Institute.Lint.Report {
    let inventory = repositories

    var targets = [(repository: Institute.Repository, target: Institute.Lint.Target)]()
    var absent = [Swift.String]()
    for repository in inventory {
      let directory = try root.materialization(for: repository)
      let identity = Institute.Repository.Key(repository: repository)?.identity ?? repository.name
      guard File(directory.path).stat.isDirectory else {
        absent.append(identity)
        continue
      }
      guard directory[file: "Package.swift"].stat.isFile else {
        absent.append(identity)
        continue
      }
      targets.append(
        (repository: repository, target: .init(package: directory, file: nil))
      )
    }

    // Ordinary lint keeps the historical empty-ecosystem hard failure.
    // Ledger mode must instead return one explicit unmaterialized row for
    // every inventory repository, even when none are present locally.
    guard format == .sarif || !targets.isEmpty || inventory.isEmpty else {
      throw .configuration(
        "UNMEASURED: \(inventory.count) packages in the inventory, none materialized under "
          + "\(lint.hierarchy). Nothing was linted. This is very likely the wrong "
          + "hierarchy root rather than an empty ecosystem — check where `workspace` was "
          + "invoked from, or pass --workspace-path."
      )
    }

    let selected: [(repository: Institute.Repository, target: Institute.Lint.Target)]
    switch scope {
    case .all:
      selected = targets
    case .changed:
      let git = self.git
      let local = await concurrently(targets) { entry in
        Self.hasLocalWork(entry.target.package, using: git)
      }
      selected = zip(targets, local).filter(\.1).map(\.0)
    }

    let installation: Institute.Lint.Installation
    do throws(Institute.Error) {
      installation = try lint.installation()
    } catch {
      guard format == .sarif else { throw error }
      return .init(
        scope: scope,
        inventory: inventory.count,
        unmaterialized: absent,
        considered: selected.count,
        measurements: selected.map { entry in
          .init(
            repository: Institute.Repository.Key(repository: entry.repository),
            package: entry.target.package.description,
            verdict: .unmeasured(
              reason: "swift-linter installation is unavailable: \(error)"
            ),
            summary: nil,
            plan: nil,
            findings: [],
            diagnostics: "",
            status: -1
          )
        }
      )
    }

    // The shadow gate applies only to a fix run: it excludes the one
    // unsafe rewriter, while leaving detection and unrelated safe
    // rewriters in that package intact.
    //
    // The scan population is every materialized package, not the
    // selected slice. Tier (b) resolves a re-exported module to the
    // package providing it, and a `--changed` sweep selects a handful
    // — resolving against that handful would report almost every
    // re-export unresolvable and exclude the unsafe rule almost everywhere.
    var excluded = [Institute.Lint.Shadow.Exclusion]()
    var shadowed = Swift.Set<Swift.String>()
    if fix != nil {
      let scans = await concurrently(targets) { entry in
        Institute.Lint.Shadow.scan(entry.target.package)
      }
      excluded = Institute.Lint.Shadow.exclusions(across: scans)
      shadowed = Swift.Set(excluded.map(\.package))
      excluded = excluded.filter { entry in
        selected.contains { $0.target.package.description == entry.package }
      }
    }

    // The bundle comes from the inventory entry's layer, which is
    // authoritative — the sweep never has to derive it from where a
    // package happens to sit on disk. It is passed for every package,
    // configured or not; `measure` uses it only for the ones with no
    // `Lint.swift`, and a configured package's own manifest always
    // wins.
    let measurements = await measure(
      selected.map { entry in
        (
          repository: Institute.Repository.Key(repository: entry.repository),
          target: entry.target,
          bundle: Institute.Lint.Bundle(entry.repository.layer),
          excluding: shadowed.contains(entry.target.package.description)
            ? [Institute.Lint.Fix.shadowedStandardLibraryQualification]
            : []
        )
      },
      using: installation,
      fix: fix,
      format: format
    )
    return .init(
      scope: scope,
      inventory: inventory.count,
      unmaterialized: absent,
      considered: targets.count,
      measurements: measurements,
      fix: fix,
      excluded: excluded
    )
  }

  /// Measures every target, `jobs` at a time.
  func measure(
    _ targets: [(
      repository: Institute.Repository.Key?,
      target: Institute.Lint.Target,
      bundle: Institute.Lint.Bundle,
      excluding: [Swift.String]
    )],
    using installation: Institute.Lint.Installation,
    fix: Institute.Lint.Fix?,
    format: Institute.Lint.Format = .text
  ) async -> [Institute.Lint.Measurement] {
    let lint = self.lint
    return await concurrently(targets) { entry in
      var measurement = lint.measure(
        entry.target,
        using: installation,
        default: entry.bundle,
        fix: fix,
        excluding: entry.excluding,
        format: format
      )
      measurement.repository = entry.repository
      return measurement
    }
  }

  /// Runs `work` over `items` with at most `jobs` in flight, returning
  /// results in input order.
  ///
  /// Bounded rather than unbounded: every unit of work here spawns a
  /// child process, and hundreds at once would thrash rather than
  /// finish sooner. Used for the scope filter as well as the
  /// measurement — the filter interrogates Git once per repository,
  /// and run sequentially over hundreds of repositories it costs more
  /// than the linting it is supposed to avoid.
  ///
  /// The bounding itself belongs to ``Async/Fanout``, which `doctor`
  /// gathers through as well. Two implementations of the same bound would
  /// be two chances to drift.
  func concurrently<Item: Sendable, Result: Sendable>(
    _ items: [Item],
    _ work: @escaping @Sendable (Item) -> Result
  ) async -> [Result] {
    await Async.Fanout(jobs: jobs).map(items, work)
  }

  /// Whether the repository at `directory` carries local work.
  ///
  /// Returns `true` when the state cannot be read. An unreadable
  /// repository is linted rather than skipped: the cost of linting one
  /// package unnecessarily is a second; the cost of skipping one
  /// silently is a false clean.
  static func hasLocalWork(
    _ directory: File.Directory,
    using git: Git.Client
  ) -> Swift.Bool {
    do throws(Git.Client.Error) {
      guard try git.repository(at: directory.description) else { return true }
      if !(try git.status(at: directory.description)).isEmpty { return true }
      let branch = try git.branch(at: directory.description)
      let upstream = try git.upstream(branch, at: directory.description)
      return try git.count("\(upstream)..HEAD", at: directory.description) > 0
    } catch {
      return true
    }
  }
}
