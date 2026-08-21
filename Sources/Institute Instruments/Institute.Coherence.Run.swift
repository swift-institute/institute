public import Build_Coordinator
public import File_System
public import Git_Foundation
public import Institute_Development
public import Institute_Doctor
public import Institute_Inventory
public import Institute_Lint
public import Institute_Model

extension Institute.Coherence {
    /// One coherence run over one selection.
    ///
    /// `sync`, `doctor`, and `build` are injected with real defaults —
    /// exactly ``Institute/Doctor``'s `tool`/`environment` pattern — so a
    /// test can substitute a fake stage without a network reach or an
    /// Xcode install, while production always walks the real pipeline.
    public struct Run: Sendable {
        public let root: Institute.Root
        public let configuration: Institute.Configuration
        public let selection: Institute.Selection.Resolved
        public let git: Git.Client

        /// The prior green receipt, if any — consulted only to diffuse
        /// `headsChangedSinceLastGreen` on an `incoherent` verdict. Receipt
        /// persistence itself is `swift-institute/.github`'s concern; this
        /// run never reads or writes one on its own.
        public let priorGreen: Receipt?

        /// Which build path measures the `graph` and `build` stages —
        /// Phase 1's `xcodebuild`-merged instrument by default, or Phase
        /// 2's `swiftpm-composed-root` (issue #81). Recorded verbatim into
        /// the receipt's `instrument.buildPath`.
        public let buildPath: Institute.Coherence.BuildPath

        public let sync:
            @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute.Error) -> Void
        public let doctor:
            @Sendable (Institute.Root, Institute.Configuration, Institute.Selection.Resolved) async
                ->
                Institute.Doctor.Report
        /// Re-renders and byte-compares the generated workspace/scheme
        /// against the current manifests, returning the expected built
        /// target count on success — the stale-scheme gate
        /// ``Institute/Xcode/Build`` already performs, injectable so a test
        /// can substitute a count without a real `institute.xcworkspace`.
        public let graph:
            @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute.Error) ->
                Swift.Int
        public let build:
            @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute.Error) ->
                Build_Coordinator.Build.Coordinator.Result

        public init(
            root: Institute.Root,
            configuration: Institute.Configuration,
            selection: Institute.Selection.Resolved,
            git: Git.Client = .init(),
            priorGreen: Receipt? = nil,
            buildPath: Institute.Coherence.BuildPath = .xcodebuildMerged,
            sync:
                @escaping @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute
                .Error)
                -> Void = Self.realSync,
            doctor:
                @escaping @Sendable (
                    Institute.Root, Institute.Configuration, Institute.Selection.Resolved
                ) async -> Institute.Doctor.Report = Self.realDoctor,
            graph: (
                @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute.Error) ->
                    Swift.Int
            )? = nil,
            build: (
                @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute.Error)
                    -> Build_Coordinator.Build.Coordinator.Result
            )? = nil
        ) {
            self.root = root
            self.configuration = configuration
            self.selection = selection
            self.git = git
            self.priorGreen = priorGreen
            self.buildPath = buildPath
            self.sync = sync
            self.doctor = doctor
            self.graph = graph ?? Self.realGraph(for: buildPath, swift: configuration.swift)
            self.build = build ?? Self.realBuild(for: buildPath)
        }
    }
}

extension Institute.Coherence.Run {
    public static func realSync(
        _ root: Institute.Root,
        _ selection: Institute.Selection.Resolved
    ) throws(Institute.Error) {
        try Institute.Sync(root: root, selection: selection).run(dry: false)
    }

    public static func realDoctor(
        _ root: Institute.Root,
        _ configuration: Institute.Configuration,
        _ selection: Institute.Selection.Resolved
    ) async -> Institute.Doctor.Report {
        await Institute.Doctor(
            root: root,
            configuration: configuration,
            selection: selection
        ).run(access: .contributor)
    }

    public static func realGraph(
        _ root: Institute.Root,
        _ selection: Institute.Selection.Resolved
    ) throws(Institute.Error) -> Swift.Int {
        let diagnostics = try Institute.Xcode.Build(root: root, selection: selection).diagnostics()
        guard diagnostics.isEmpty else {
            throw .configuration(diagnostics.joined(separator: "\n"))
        }
        let specification = try Institute.Xcode.specification(selection.repositories)
        return try Institute.Xcode.Scheme.plan(for: specification, at: root).buildables.count
    }

    public static func realBuild(
        _ root: Institute.Root,
        _ selection: Institute.Selection.Resolved
    ) throws(Institute.Error) -> Build_Coordinator.Build.Coordinator.Result {
        try Institute.Xcode.Build(root: root, selection: selection).run(
            fresh: false,
            arguments: [],
            capturingDiagnostics: true
        )
    }

    /// Generates the composed root fresh from the current selection's
    /// manifests and returns its reachable population — Phase 2's `graph`
    /// stage. There is no separate staleness gate here (unlike
    /// ``realGraph(_:_:)``'s scheme byte-compare): ``Composed/Root/write``
    /// regenerates the directory unconditionally, so the count it returns
    /// is always current for this run.
    public static func realComposedGraph(
        swift: Swift.String
    )
        -> @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute.Error) ->
        Swift.Int
    {
        { root, selection in
            let manifests = try Institute.Composed.manifests(for: selection.repositories, at: root)
            try Institute.Composed.Root.write(manifests, swift: swift, in: .checkout(root.checkout))
            return Institute.Composed.Root.expectedTargetCount(in: manifests)
        }
    }

    public static func realComposedBuild(
        _ root: Institute.Root,
        _ selection: Institute.Selection.Resolved
    ) throws(Institute.Error) -> Build_Coordinator.Build.Coordinator.Result {
        try Institute.Composed.Root.build(
            in: .checkout(root.checkout),
            fresh: false,
            arguments: [],
            capturingDiagnostics: true
        )
    }

    /// Selects the real `graph` stage for `buildPath`, capturing `swift`
    /// (the declared tools-version floor) for the composed-root path's
    /// generated manifest header.
    public static func realGraph(
        for buildPath: Institute.Coherence.BuildPath,
        swift: Swift.String
    )
        -> @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute.Error) ->
        Swift.Int
    {
        switch buildPath {
        case .xcodebuildMerged: Self.realGraph
        case .swiftPMComposedRoot: Self.realComposedGraph(swift: swift)
        }
    }

    /// Selects the real `build` stage for `buildPath`.
    public static func realBuild(
        for buildPath: Institute.Coherence.BuildPath
    )
        -> @Sendable (Institute.Root, Institute.Selection.Resolved) throws(Institute.Error) ->
        Build_Coordinator.Build.Coordinator.Result
    {
        switch buildPath {
        case .xcodebuildMerged: Self.realBuild
        case .swiftPMComposedRoot: Self.realComposedBuild
        }
    }
}

extension Institute.Coherence.Run {
    /// Walks every stage and returns the receipt — never throws, so a
    /// failure this instrument encounters becomes an entry in the receipt
    /// rather than a process failure with no comparable record.
    public func run() async -> Institute.Coherence.Receipt {
        let clock = Swift.ContinuousClock()
        var stages: [Institute.Coherence.StageResult] = [
            .init(stage: .bootstrap, outcome: .success, durationSeconds: 0)
        ]
        var attribution: Institute.Coherence.Attribution?
        var proceed = true

        // sync
        if proceed {
            let started = clock.now
            do throws(Institute.Error) {
                try sync(root, selection)
                stages.append(
                    .init(
                        stage: .sync,
                        outcome: .success,
                        durationSeconds: Self.seconds(clock.now - started)
                    )
                )
            } catch {
                stages.append(
                    .init(
                        stage: .sync,
                        outcome: .failure,
                        durationSeconds: Self.seconds(clock.now - started)
                    )
                )
                proceed = false
            }
        } else {
            stages.append(.init(stage: .sync, outcome: .notRun, durationSeconds: 0))
        }

        // doctor
        if proceed {
            let started = clock.now
            let report = await doctor(root, configuration, selection)
            let ok = report.status == 0
            stages.append(
                .init(
                    stage: .doctor,
                    outcome: ok ? .success : .failure,
                    durationSeconds: Self.seconds(clock.now - started)
                )
            )
            if !ok { proceed = false }
        } else {
            stages.append(.init(stage: .doctor, outcome: .notRun, durationSeconds: 0))
        }

        // graph
        var expectedTargetCount = 0
        if proceed {
            let started = clock.now
            do throws(Institute.Error) {
                expectedTargetCount = try graph(root, selection)
                stages.append(
                    .init(
                        stage: .graph,
                        outcome: .success,
                        durationSeconds: Self.seconds(clock.now - started)
                    )
                )
            } catch {
                stages.append(
                    .init(
                        stage: .graph,
                        outcome: .failure,
                        durationSeconds: Self.seconds(clock.now - started)
                    )
                )
                proceed = false
            }
        } else {
            stages.append(.init(stage: .graph, outcome: .notRun, durationSeconds: 0))
        }

        // build
        var builtTargetCount = 0
        var buildSucceeded = false
        if proceed {
            let started = clock.now
            do throws(Institute.Error) {
                let result = try build(root, selection)
                let elapsed = Self.seconds(clock.now - started)
                if result.exitCode == 0 {
                    buildSucceeded = true
                    builtTargetCount = expectedTargetCount
                    stages.append(.init(stage: .build, outcome: .success, durationSeconds: elapsed))
                } else {
                    stages.append(.init(stage: .build, outcome: .failure, durationSeconds: elapsed))
                    let diagnostic = Institute.Coherence.firstDiagnostic(
                        standardOutput: result.standardOutput,
                        standardError: result.standardError
                    )
                    let repository = Institute.Coherence.attribute(
                        diagnostic,
                        repositories: selection.repositories,
                        root: root
                    )
                    attribution = .init(
                        stage: .build,
                        package: repository?.name,
                        organization: repository?.organization,
                        layer: repository?.layer.rawValue,
                        firstDiagnostic: diagnostic,
                        headsChangedSinceLastGreen: []
                    )
                    proceed = false
                }
            } catch {
                // A thrown `Institute.Error` here is the build coordinator
                // failing to invoke `xcodebuild` at all (a process or
                // filesystem defect) — not a compile diagnostic about the
                // graph. It carries no package attribution and is reported
                // as `unmeasured`, exactly like an earlier-stage failure,
                // rather than manufacturing a false `incoherent` verdict.
                stages.append(
                    .init(
                        stage: .build,
                        outcome: .failure,
                        durationSeconds: Self.seconds(clock.now - started)
                    )
                )
                proceed = false
            }
        } else {
            stages.append(.init(stage: .build, outcome: .notRun, durationSeconds: 0))
        }

        // population
        let inventoryCount = configuration.repositories.count
        let materializedCount = selection.repositories.count
        let canonical: Swift.Bool
        if case .committed = selection.origin { canonical = true } else { canonical = false }

        let population = Institute.Coherence.Population(
            inventoryCount: inventoryCount,
            materializedCount: materializedCount,
            builtTargetCount: builtTargetCount,
            expectedTargetCount: expectedTargetCount
        )

        let verdict: Institute.Coherence.Verdict
        if buildSucceeded {
            let coverageOK = !canonical || materializedCount == inventoryCount
            let targetsOK = builtTargetCount == expectedTargetCount
            if coverageOK, targetsOK {
                stages.append(.init(stage: .population, outcome: .success, durationSeconds: 0))
                verdict = .coherent
            } else {
                stages.append(.init(stage: .population, outcome: .failure, durationSeconds: 0))
                verdict = .unmeasured
            }
        } else {
            stages.append(.init(stage: .population, outcome: .notRun, durationSeconds: 0))
            verdict = attribution == nil ? .unmeasured : .incoherent
        }

        if let priorGreen, var completed = attribution {
            completed = .init(
                stage: completed.stage,
                package: completed.package,
                organization: completed.organization,
                layer: completed.layer,
                firstDiagnostic: completed.firstDiagnostic,
                headsChangedSinceLastGreen: Self.changedHeads(from: priorGreen.heads, to: heads())
            )
            attribution = completed
        }

        let selectionField = canonical ? "policy" : Self.narrowingDescription(selection.origin)
        return .init(
            instrument: .init(
                workspaceCommit: Self.line(
                    {
                        do throws(Institute.Error) {
                            return try Institute.Doctor.spawn(
                                "git",
                                arguments: ["-C", root.checkout.description, "rev-parse", "HEAD"]
                            )
                        } catch {
                            return nil
                        }
                    }()
                ),
                workspaceJsonBlob: Self.line(
                    {
                        do throws(Institute.Error) {
                            return try Institute.Doctor.spawn(
                                "git",
                                arguments: [
                                    "-C", root.checkout.description, "rev-parse",
                                    "HEAD:Institute.json",
                                ]
                            )
                        } catch {
                            return nil
                        }
                    }()
                ),
                selection: selectionField,
                buildPath: buildPath.rawValue
            ),
            environment: .init(
                platform: Self.currentPlatform,
                swift: configuration.swift,
                xcode: configuration.xcode,
                runner: Self.runnerDescription(),
                fresh: false,
                cachesUsed: []
            ),
            population: population,
            heads: stages.first(where: { $0.stage == .sync })?.outcome == .success ? heads() : [:],
            stages: stages,
            verdict: verdict,
            attribution: attribution,
            priorGreenReceipt: nil
        )
    }

    /// One "org/repository" → HEAD-of-`main` entry per selected repository
    /// whose materialized checkout is currently readable. Best-effort: a
    /// repository whose head cannot be read is omitted rather than failing
    /// the whole run — this map feeds attribution's head-diff, it does not
    /// gate the verdict.
    private func heads() -> [Swift.String: Swift.String] {
        var heads = [Swift.String: Swift.String]()
        for repository in selection.repositories {
            let directory: File.Directory
            do throws(Institute.Error) {
                directory = try root.materialization(for: repository)
            } catch {
                continue
            }
            let head: Git.Object.ID
            do throws(Git.Client.Error) {
                head = try git.head("main", at: directory.description)
            } catch {
                continue
            }
            heads["\(repository.organization)/\(repository.name)"] = head.rawValue
        }
        return heads
    }

    private static func changedHeads(
        from previous: [Swift.String: Swift.String],
        to current: [Swift.String: Swift.String]
    ) -> [Swift.String] {
        var changed = [Swift.String]()
        for (identity, head) in current where previous[identity] != head {
            changed.append("\(identity)@\(head)")
        }
        return changed.sorted()
    }

    private static func narrowingDescription(_ origin: Institute.Selection.Origin) -> Swift.String {
        "narrowed(+\(origin.added.count)/-\(origin.removed.count))"
    }

    /// `Institute.Doctor.variable` rather than a direct `Environment.read`
    /// here: inside `extension Institute.Coherence.Run` the unqualified
    /// name `Environment` resolves to ``Coherence/Environment`` (the
    /// receipt's own nested type) first, exactly the shadow
    /// `Institute.Xcode.Scheme` documents for its own `Xcode` collision.
    /// Routing through the already-imported `Institute.Doctor` avoids
    /// needing a module-qualified spelling of the swift-environment
    /// product here at all.
    private static func runnerDescription() -> Swift.String {
        Institute.Doctor.variable("GITHUB_ACTIONS") != nil ? "github-hosted" : "local"
    }

    /// The platform this run actually measures on — literal `"macos"`
    /// under Phase 1 today, but the `swiftpm-composed-root` build path
    /// (issue #81) is Ubuntu-capable, so the receipt must not hardcode a
    /// single platform regardless of what compiled it.
    public static var currentPlatform: Swift.String {
        #if os(macOS)
            "macos"
        #elseif os(Linux)
            "linux"
        #elseif os(Windows)
            "windows"
        #else
            "unknown"
        #endif
    }

    /// The first line of a spawned tool's output, or `"unknown"` when the
    /// interrogation itself failed — this metadata is descriptive, not
    /// gating, so a failure here must never fail the run.
    private static func line(_ value: Swift.String?) -> Swift.String {
        guard let value else { return "unknown" }
        return value.split(separator: "\n").first.map(Swift.String.init) ?? "unknown"
    }

    private static func seconds(_ duration: Swift.Duration) -> Swift.Double {
        let components = duration.components
        return Swift.Double(components.seconds) + Swift.Double(components.attoseconds) / 1e18
    }
}
