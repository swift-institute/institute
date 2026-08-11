public import Build_Coordinator
public import File_System
public import Git_Foundation
public import Institute_Development
public import Institute_Doctor
public import Institute_Inventory
public import Institute_Lint
public import Institute_Model

extension Institute.Verification {
  /// One verification run over one subject package: performs the
  /// requested operations against ``packagePath`` and seals a
  /// content-addressed ``Receipt`` (Task 2-01).
  ///
  /// **Why so many facts are caller-supplied rather than derived here.**
  /// A verification run must stay a fast, offline, credential-free leaf
  /// operation — Task 2-02's read-only verifier mints no write-capable
  /// token and must not need a live network reach to seal evidence. Every
  /// fact this run cannot establish by inspecting `packagePath` itself
  /// (its coordinate's visibility, its effective-inventory layer and
  /// digest, the pinned Institute revision measuring it, the control
  /// plane's policy revision) is therefore a parameter, not a derivation:
  /// the control plane that already resolved those facts from the live
  /// effective inventory (0C-02) and its own pinned checkout supplies
  /// them, and this run never re-derives or invents one it was not
  /// given — the same discipline producer requirement 4 states for
  /// hosted image identity, applied to every caller-supplied fact.
  ///
  /// **What this run does establish itself:** the subject's observed
  /// head and working-tree cleanliness (``Git/Client``), the toolchain
  /// and host it is measuring on (``Environment/observe()``), and the
  /// result of every requested operation, by actually running it through
  /// ``Build/Coordinator`` (build, test, nested test packages) or
  /// ``Institute/Lint`` (lint).
  ///
  /// Every real-tool interaction is injectable, exactly the
  /// ``Institute/Coherence/Run`` and ``Institute/Conversion/Seal``
  /// pattern: production always walks the real closures; a test
  /// substitutes a fake without a real package checkout.
  public struct Run: Sendable {
    public let packagePath: Swift.String
    public let claimedHead: Swift.String
    public let coordinate: Institute.Repository.Key
    public let visibility: Institute.Verification.Visibility
    public let visibilityReason: Swift.String?
    public let defaultBranch: Swift.String
    public let layer: Institute.Layer
    public let inventoryDigest: Institute.Verification.Inventory.Digest
    public let workspaceRevision: Swift.String
    public let policyRevision: Swift.String
    public let requestedOperations: [Operation.Kind]
    public let requiredOperations: [Operation.Kind]
    public let platformSupport: [Swift.String]
    public let fresh: Swift.Bool
    public let jobs: Swift.Int?
    public let arguments: [Swift.String]
    let tools: Tools

    /// The public entry point — always walks the real tool closures.
    /// `Tools` itself stays internal (it is only an injection seam for
    /// this module's own tests), so it cannot appear in a `public`
    /// initializer's signature; this forwards to the internal
    /// designated initializer with the real defaults.
    public init(
      packagePath: Swift.String,
      claimedHead: Swift.String,
      coordinate: Institute.Repository.Key,
      visibility: Institute.Verification.Visibility,
      visibilityReason: Swift.String? = nil,
      defaultBranch: Swift.String,
      layer: Institute.Layer,
      inventoryDigest: Institute.Verification.Inventory.Digest,
      workspaceRevision: Swift.String,
      policyRevision: Swift.String,
      requestedOperations: [Operation.Kind],
      requiredOperations: [Operation.Kind],
      platformSupport: [Swift.String] = [],
      fresh: Swift.Bool = false,
      jobs: Swift.Int? = nil,
      arguments: [Swift.String] = []
    ) {
      self.init(
        packagePath: packagePath,
        claimedHead: claimedHead,
        coordinate: coordinate,
        visibility: visibility,
        visibilityReason: visibilityReason,
        defaultBranch: defaultBranch,
        layer: layer,
        inventoryDigest: inventoryDigest,
        workspaceRevision: workspaceRevision,
        policyRevision: policyRevision,
        requestedOperations: requestedOperations,
        requiredOperations: requiredOperations,
        platformSupport: platformSupport,
        fresh: fresh,
        jobs: jobs,
        arguments: arguments,
        tools: Tools()
      )
    }

    /// The designated initializer — internal because ``Tools`` is
    /// internal. Exists so this module's own tests can substitute fake
    /// tool closures without a real package checkout.
    init(
      packagePath: Swift.String,
      claimedHead: Swift.String,
      coordinate: Institute.Repository.Key,
      visibility: Institute.Verification.Visibility,
      visibilityReason: Swift.String? = nil,
      defaultBranch: Swift.String,
      layer: Institute.Layer,
      inventoryDigest: Institute.Verification.Inventory.Digest,
      workspaceRevision: Swift.String,
      policyRevision: Swift.String,
      requestedOperations: [Operation.Kind],
      requiredOperations: [Operation.Kind],
      platformSupport: [Swift.String] = [],
      fresh: Swift.Bool = false,
      jobs: Swift.Int? = nil,
      arguments: [Swift.String] = [],
      tools: Tools
    ) {
      self.packagePath = packagePath
      self.claimedHead = claimedHead
      self.coordinate = coordinate
      self.visibility = visibility
      self.visibilityReason = visibilityReason
      self.defaultBranch = defaultBranch
      self.layer = layer
      self.inventoryDigest = inventoryDigest
      self.workspaceRevision = workspaceRevision
      self.policyRevision = policyRevision
      self.requestedOperations = requestedOperations
      self.requiredOperations = requiredOperations
      self.platformSupport = platformSupport
      self.fresh = fresh
      self.jobs = jobs
      self.arguments = arguments
      self.tools = tools
    }
  }
}

extension Institute.Verification.Run {
  /// Every real-tool interaction ``Run`` performs, bundled as one
  /// injectable value instead of eight separate initializer parameters.
  ///
  /// Split out deliberately, not only for readability: a single
  /// initializer assigning sixteen plain facts and eight `@Sendable`
  /// closures (several with a `parameter ?? Self.realX` fallback) is
  /// exactly the shape that crashed `swift-frontend` during IR
  /// generation for `Run.init` on this toolchain — see the programme's
  /// `toolchain-defects.md`. Splitting the closure-bearing parameters
  /// into their own small type with its own defaults resolves the
  /// crash and is the better design independent of that: every real/fake
  /// pair now sits next to its sibling instead of spread across a
  /// twenty-three-parameter initializer.
  ///
  /// Production always uses the defaults (every real closure); a test
  /// substitutes only the ones it needs to fake, exactly the
  /// ``Institute/Coherence/Run`` pattern applied one level down.
  struct Tools: Sendable {
    var head: @Sendable (Swift.String) throws(Institute.Error) -> Swift.String
    var dirty: @Sendable (Swift.String) throws(Institute.Error) -> Swift.Bool
    var build:
      @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
        Institute.Verification.Operation.Result
    var test:
      @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
        Institute.Verification.Operation.Result
    var nestedTests:
      @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
        [Institute.Verification.Operation.Result]
    var lint: @Sendable (Swift.String) -> Institute.Verification.Operation.Result
    var environment: @Sendable () -> Institute.Verification.Environment
    var now: @Sendable () -> Swift.String

    init(
      head: @escaping @Sendable (Swift.String) throws(Institute.Error) -> Swift.String =
        Institute.Verification.Run.realHead,
      dirty: @escaping @Sendable (Swift.String) throws(Institute.Error) -> Swift.Bool =
        Institute.Verification.Run.realDirty,
      build:
        @escaping @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
        Institute.Verification.Operation.Result = Institute.Verification.Run.realBuild,
      test:
        @escaping @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
        Institute.Verification.Operation.Result = Institute.Verification.Run.realTest,
      nestedTests:
        @escaping @Sendable (Swift.String, Swift.Bool, Swift.Int?, [Swift.String]) ->
        [Institute.Verification.Operation.Result] = Institute.Verification.Run.realNestedTests,
      lint: @escaping @Sendable (Swift.String) -> Institute.Verification.Operation.Result =
        Institute.Verification.Run.realLint,
      environment: @escaping @Sendable () -> Institute.Verification.Environment =
        Institute.Verification.Environment.observe,
      now: @escaping @Sendable () -> Swift.String = Institute.Verification.Run.realNow
    ) {
      self.head = head
      self.dirty = dirty
      self.build = build
      self.test = test
      self.nestedTests = nestedTests
      self.lint = lint
      self.environment = environment
      self.now = now
    }
  }
}

extension Institute.Verification.Run {
  static func realHead(_ path: Swift.String) throws(Institute.Error) -> Swift.String {
    do throws(Git.Client.Error) {
      return try Git.Client().head(at: path).rawValue
    } catch {
      throw .process("cannot read the subject HEAD at \(path): \(error)")
    }
  }

  static func realDirty(_ path: Swift.String) throws(Institute.Error) -> Swift.Bool {
    do throws(Git.Client.Error) {
      return try !Git.Client().status(at: path).isEmpty
    } catch {
      throw .process("cannot read the subject working-tree status at \(path): \(error)")
    }
  }

  /// `date -u` rather than Foundation's `Date` — this module stays
  /// Foundation-free, and every other wall-clock-adjacent fact in it
  /// (``Institute/Doctor/spawn``'s callers) already reaches the system
  /// through a spawned tool rather than a linked framework.
  static func realNow() -> Swift.String {
    let output: Swift.String
    do throws(Institute.Error) {
      output = try Institute.Doctor.spawn("date", arguments: ["-u", "+%Y-%m-%dT%H:%M:%SZ"])
    } catch {
      return "unknown"
    }
    return output.split(separator: "\n").first.map(Swift.String.init) ?? "unknown"
  }
}

extension Institute.Verification.Run {
  /// Runs one `Build.Action` at `request.path` and folds the coordinator's
  /// result into an ``Operation/Result``. Shared by ``realBuild``,
  /// ``realTest``, and each nested test package ``realNestedTests``
  /// discovers.
  static func run(
    _ operation: Institute.Verification.Operation.Kind,
    request: Institute.Verification.Operation.Request,
    started: Swift.String,
    now: @Sendable () -> Swift.String
  ) -> Institute.Verification.Operation.Result {
    let clock = Swift.ContinuousClock()
    let clockStart = clock.now
    let coordinator = Build.Coordinator(jobs: request.jobs)
    let outcome: Institute.Verification.Operation.Outcome
    let exitCode: Swift.Int32?
    var compileEvidence: Swift.String?
    var testCounts: Institute.Verification.Operation.TestCounts?
    do throws(Build.Error) {
      let result = try coordinator.run(
        request.action,
        at: request.path,
        fresh: request.fresh,
        arguments: request.arguments,
        capturingDiagnostics: true
      )
      exitCode = result.exitCode
      if result.exitCode == 0 {
        outcome = .success
        if request.action == .test {
          testCounts = Self.parseTestCounts(
            Swift.String(decoding: result.standardOutput ?? [], as: Swift.UTF8.self)
          )
        }
      } else {
        outcome = .failure
        compileEvidence = Institute.Coherence.firstDiagnostic(
          standardOutput: result.standardOutput,
          standardError: result.standardError
        )
      }
    } catch {
      exitCode = nil
      outcome = .unmeasured(
        reason: "the build coordinator could not run \(request.action.rawValue): \(error)")
    }
    return .init(
      operation: operation,
      subpath: request.subpath,
      arguments: request.arguments,
      startedAt: started,
      endedAt: now(),
      durationSeconds: Self.seconds(clock.now - clockStart),
      exitCode: exitCode,
      provenance: request.fresh ? .fresh : .cached,
      outcome: outcome,
      compileEvidence: compileEvidence,
      testCounts: testCounts,
      findings: []
    )
  }

  /// The same `Duration` → seconds reduction
  /// ``Institute/Coherence/Run/seconds(_:)`` uses.
  static func seconds(_ duration: Swift.Duration) -> Swift.Double {
    let components = duration.components
    return Swift.Double(components.seconds) + Swift.Double(components.attoseconds) / 1e18
  }

  static func realBuild(
    _ path: Swift.String,
    _ fresh: Swift.Bool,
    _ jobs: Swift.Int?,
    _ arguments: [Swift.String]
  ) -> Institute.Verification.Operation.Result {
    Self.run(
      .build,
      request: .init(
        action: .build,
        path: path,
        subpath: nil,
        fresh: fresh,
        jobs: jobs,
        arguments: arguments
      ),
      started: Self.realNow(),
      now: Self.realNow
    )
  }

  static func realTest(
    _ path: Swift.String,
    _ fresh: Swift.Bool,
    _ jobs: Swift.Int?,
    _ arguments: [Swift.String]
  ) -> Institute.Verification.Operation.Result {
    Self.run(
      .test,
      request: .init(
        action: .test,
        path: path,
        subpath: nil,
        fresh: fresh,
        jobs: jobs,
        arguments: arguments
      ),
      started: Self.realNow(),
      now: Self.realNow
    )
  }

  /// A best-effort parse of `swift test`'s final summary line, in either
  /// shape this ecosystem's targets can emit: XCTest's `Executed N
  /// tests, with F failures …`, or Swift Testing's `Test run with N
  /// tests in M suites passed/failed after T seconds …`. Returns `nil`
  /// — never a guessed count — whenever a line matches one shape's
  /// opening words but not its exact number-bearing tokens, exactly the
  /// discipline ``Institute/Lint/Summary/parse(_:)`` already applies to
  /// swift-linter's own run summary.
  static func parseTestCounts(
    _ output: Swift.String
  ) -> Institute.Verification.Operation.TestCounts? {
    for line in output.split(separator: "\n", omittingEmptySubsequences: true) {
      if let counts = Self.parseXCTestSummary(line) { return counts }
      if let counts = Self.parseSwiftTestingSummary(line) { return counts }
    }
    return nil
  }

  /// `Executed 5 tests, with 0 failures (0 unexpected) in 0.012 (0.014)
  /// seconds`.
  private static func parseXCTestSummary(
    _ line: Swift.Substring
  ) -> Institute.Verification.Operation.TestCounts? {
    guard line.contains("Executed"), line.contains("test") else { return nil }
    let tokens = line.split(separator: " ")
    guard
      let executedIndex = tokens.firstIndex(of: "Executed"),
      executedIndex + 1 < tokens.count,
      let executed = Swift.Int(tokens[executedIndex + 1]),
      let withIndex = tokens.firstIndex(of: "with"),
      withIndex + 1 < tokens.count,
      let failed = Swift.Int(tokens[withIndex + 1])
    else { return nil }
    return .init(executed: executed, passed: executed - failed, failed: failed)
  }

  /// `Test run with 5 tests in 2 suites passed after 0.012 seconds.` or
  /// `… failed after 0.012 seconds with 2 issues (including 1 known
  /// issue).` — the executed count sits right after the first `with`;
  /// the failure count, when the run failed, sits right after the
  /// second. A `passed` line with no second `with` is 0 failures by
  /// construction, never a guess.
  private static func parseSwiftTestingSummary(
    _ line: Swift.Substring
  ) -> Institute.Verification.Operation.TestCounts? {
    guard line.hasPrefix("Test run with"), line.contains("test") else { return nil }
    let tokens = line.split(separator: " ")
    guard
      let firstWith = tokens.firstIndex(of: "with"),
      firstWith + 1 < tokens.count,
      let executed = Swift.Int(tokens[firstWith + 1])
    else { return nil }
    if line.contains(" passed ") {
      return .init(executed: executed, passed: executed, failed: 0)
    }
    guard
      line.contains(" failed "),
      let secondWith = tokens[(firstWith + 1)...].firstIndex(of: "with"),
      secondWith + 1 < tokens.count,
      let failed = Swift.Int(tokens[secondWith + 1])
    else { return nil }
    return .init(executed: executed, passed: executed - failed, failed: failed)
  }
}

extension Institute.Verification.Run {
  /// Discovers every nested test package under `Tests/` — a `Package.swift`
  /// one level below `Tests/`, the shape the testing skill documents for a
  /// snapshot suite needing a third-party test dependency the main
  /// manifest does not carry — and runs `swift test` in each. An absent
  /// `Tests/` directory or one containing no nested manifest is not an
  /// error: it means this subject has none, which
  /// ``Institute/Verification/Run/run()`` records as `notApplicable`
  /// when nothing is returned here.
  static func realNestedTests(
    _ path: Swift.String,
    _ fresh: Swift.Bool,
    _ jobs: Swift.Int?,
    _ arguments: [Swift.String]
  ) -> [Institute.Verification.Operation.Result] {
    let testsComponent: File.Path.Component
    do throws(File.Path.Component.Error) {
      testsComponent = try File.Path.Component("Tests")
    } catch {
      return []
    }
    let root: File.Directory
    do throws(File.Path.Error) {
      root = try File.Directory(validating: path)
    } catch {
      return []
    }
    let tests = root[directory: testsComponent]
    guard File(tests.path).stat.isDirectory else { return [] }

    let entries: [File.Directory.Entry]
    do throws(File.Directory.Contents.Error) {
      entries = try File.Directory.Contents.list(at: tests)
    } catch {
      return []
    }

    var results: [Institute.Verification.Operation.Result] = []
    for entry in entries where entry.type == .directory {
      guard let name = Swift.String(entry.name) else { continue }
      let component: File.Path.Component
      do throws(File.Path.Component.Error) {
        component = try File.Path.Component(name)
      } catch {
        continue
      }
      let nested = tests[directory: component]
      guard nested[file: "Package.swift"].stat.exists else { continue }
      results.append(
        Self.run(
          .nestedTests,
          request: .init(
            action: .test,
            path: nested.description,
            subpath: "Tests/\(name)",
            fresh: fresh,
            jobs: jobs,
            arguments: arguments
          ),
          started: Self.realNow(),
          now: Self.realNow
        )
      )
    }
    return results
  }
}

extension Institute.Verification.Run {
  /// Runs the same per-package lint gate `institute package lint`
  /// already performs (``Institute/CLI/run()``'s `.package`/`.lint`
  /// branch), folded into an ``Operation/Result``.
  static func realLint(_ path: Swift.String) -> Institute.Verification.Operation.Result {
    let started = Self.realNow()
    // Each stage is caught separately so the sealed reason can name
    // *which* stage refused. The old single `catch` interpolated the
    // error's captured message to get that detail, and the message
    // routinely quotes this machine's filesystem — see `Refusal`.
    let target: Institute.Lint.Target
    do throws(Institute.Error) {
      target = try Institute.Lint.Target.resolve(path)
    } catch {
      return Self.refusedLint(.unresolvableTarget(error.kind), started: started)
    }
    let lint: Institute.Lint
    do throws(Institute.Error) {
      lint = try Institute.Lint.resolve(from: target.package.description)
    } catch {
      return Self.refusedLint(.unresolvableConfiguration(error.kind), started: started)
    }
    let installation: Institute.Lint.Installation
    do throws(Institute.Error) {
      installation = try lint.installation()
    } catch {
      return Self.refusedLint(.unavailableInstallation(error.kind), started: started)
    }
    let measurement = lint.measure(
      target,
      using: installation,
      default: Institute.Lint.Bundle.resolve(target.package, under: lint.hierarchy),
      fix: nil
    )
    let outcome: Institute.Verification.Operation.Outcome
    switch measurement.verdict {
    case .clean:
      outcome = .success

    case .violations(_, let failing):
      outcome = failing ? .failure : .success

    case .unmeasured(let reason):
      // The engine's own unmeasured reasons quote the package and
      // hierarchy paths it was given (see `Institute.Lint.Run`'s
      // no-bundle branch), so the reason is relativized first and
      // withheld entirely if anything unsealable survives.
      let relative = Institute.Verification.Redaction.relative(reason, to: path)
      outcome =
        Institute.Verification.Redaction.diagnose(relative) == nil
        ? .unmeasured(reason: relative)
        : .unmeasured(reason: Refusal.unsealableMeasurementReason.description)
    }
    return .init(
      operation: .lint,
      arguments: [],
      startedAt: started,
      endedAt: Self.realNow(),
      durationSeconds: Self.seconds(measurement.duration),
      exitCode: measurement.status,
      provenance: .cached,
      outcome: outcome,
      // swift-linter reports the files it was pointed at, which on a
      // hosted runner means an absolute path per finding — content
      // `run()` refuses to seal. Relativizing here keeps the finding
      // whole and makes the lint leg sealable at all; a finding that
      // still names some *other* absolute path is left to that
      // refusal, deliberately.
      // Relativized centrally in `run()`, with every other leg.
      findings: Swift.Array(measurement.findings.prefix(50))
    )
  }

  /// One leak-safe unmeasured lint result — the shape every refusal
  /// stage in ``realLint(_:)`` returns.
  private static func refusedLint(
    _ refusal: Refusal,
    started: Swift.String
  ) -> Institute.Verification.Operation.Result {
    .init(
      operation: .lint,
      arguments: [],
      startedAt: started,
      endedAt: Self.realNow(),
      durationSeconds: 0,
      exitCode: nil,
      provenance: .cached,
      outcome: .unmeasured(reason: refusal.description),
      findings: []
    )
  }
}

extension Institute.Verification.Run {
  /// Performs every requested operation and seals a ``Receipt`` — or
  /// refuses with a typed ``Error`` when this run cannot honestly claim
  /// to have verified the subject. See ``Error`` for exactly which
  /// conditions refuse rather than seal an ``Verdict/unverified``
  /// receipt, and why the distinction matters.
  public func run() throws(Institute.Verification.Error) -> Institute.Verification.Receipt {
    let observedHead: Swift.String
    let isDirty: Swift.Bool
    do throws(Institute.Error) {
      observedHead = try tools.head(packagePath)
      isDirty = try tools.dirty(packagePath)
    } catch {
      throw .subject("\(error)")
    }
    guard observedHead == claimedHead else {
      throw .headMismatch(claimed: claimedHead, observed: observedHead)
    }
    guard !isDirty else {
      throw .dirtySubject(packagePath)
    }

    var results: [Institute.Verification.Operation.Result] = []
    for kind in requestedOperations {
      switch kind {
      case .build:
        results.append(tools.build(packagePath, fresh, jobs, arguments))

      case .test:
        results.append(tools.test(packagePath, fresh, jobs, arguments))

      case .nestedTests:
        let nested = tools.nestedTests(packagePath, fresh, jobs, arguments)
        if nested.isEmpty {
          results.append(
            .init(
              operation: .nestedTests,
              arguments: [],
              startedAt: tools.now(),
              endedAt: tools.now(),
              durationSeconds: 0,
              exitCode: nil,
              provenance: fresh ? .fresh : .cached,
              outcome: .notApplicable(reason: "no nested test package under Tests/"),
              findings: []
            )
          )
        } else {
          results.append(contentsOf: nested)
        }

      case .lint:
        results.append(tools.lint(packagePath))
      }
    }

    guard results.contains(where: { $0.outcome.isExecuted }) else {
      throw .noOperationExecuted
    }

    var gates: [Institute.Verification.Gate] = []
    for required in requiredOperations {
      let matches = results.filter { $0.operation == required }
      guard !matches.isEmpty else {
        throw .requiredOperationMissing(required)
      }
      guard matches.allSatisfy({ $0.outcome.isExecuted }) else {
        throw .requiredOperationNotExecuted(required)
      }
      gates.append(
        .init(
          name: required.rawValue,
          satisfied: matches.allSatisfy { $0.outcome.isSatisfying }
        )
      )
    }

    // One place, every leg: captured tool output names the subject by
    // the absolute path the tool was pointed at, and the boundary
    // below refuses exactly that. Rewriting it here — not in each
    // producer — is what keeps the rule a property of the boundary.
    results = results.map { $0.relative(to: packagePath) }

    for result in results {
      if let evidence = result.compileEvidence,
        let reason = Institute.Verification.Redaction.diagnose(evidence)
      {
        throw .unsafeContent("operation \(result.operation.rawValue) compile evidence \(reason)")
      }
      for finding in result.findings {
        if let reason = Institute.Verification.Redaction.diagnose(finding) {
          throw .unsafeContent("operation \(result.operation.rawValue) finding \(reason)")
        }
      }
    }

    let verdict: Institute.Verification.Verdict
    if gates.allSatisfy(\.satisfied), results.allSatisfy({ $0.outcome.isSatisfying }) {
      verdict = .verified
    } else {
      verdict = .unverified(
        reason: "one or more executed operations did not reach a satisfying outcome"
      )
    }

    return Institute.Verification.Receipt(
      subject: .init(
        coordinate: coordinate,
        visibility: visibility,
        visibilityReason: visibilityReason,
        defaultBranch: defaultBranch,
        claimedHead: claimedHead,
        observedHead: observedHead,
        dirty: isDirty
      ),
      inventoryDigest: inventoryDigest,
      layer: layer,
      workspaceRevision: workspaceRevision,
      policyRevision: policyRevision,
      environment: tools.environment(),
      requestedOperations: requestedOperations,
      operations: results,
      platform: .init(
        declared: platformSupport,
        measured: Institute.Verification.Environment.currentOS
      ),
      requiredGates: gates,
      verdict: verdict
    )
  }
}
