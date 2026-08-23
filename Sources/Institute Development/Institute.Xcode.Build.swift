public import File_System
public import Institute_Build_Coordinator
public import Institute_Inventory
public import Institute_Model

extension Institute.Xcode {
    /// Builds the whole selection in one `xcodebuild` invocation, through the
    /// generated `institute interim.xcworkspace`.
    ///
    /// The alternative this replaces is N invocations of
    /// `institute package build`, one per selected package. Those cannot
    /// overlap: the build coordinator holds a machine-wide exclusive lock
    /// across the whole compilation, so the effective parallelism of a
    /// multi-package sweep is one, whatever `jobs` says. They also do not
    /// share work — each package gets its own `.build`, so a dependency
    /// common to several selected packages is compiled once per package.
    ///
    /// And they build the wrong sources. `swift build` resolves a package's
    /// dependencies from pinned remotes: change a selected package on disk
    /// and a consumer's `swift build` will compile the published version and
    /// report success. The workspace resolves its members from local paths,
    /// so this is the only path that builds the institute from the working
    /// copy. That, not speed, is the reason it exists.
    ///
    /// The integration scheme covers the selected subjects plus the currently
    /// admitted typed controls. Controls remain separate from the subject
    /// cohort even though Xcode builds their exact targets in the same graph.
    public struct Build: Sendable {
        public let root: Institute.Root
        public let selection: Institute.Selection.Resolved

        public init(root: Institute.Root, selection: Institute.Selection.Resolved) {
            self.root = root
            self.selection = selection
        }
    }
}

extension Institute.Xcode.Build {
    public var bundle: File.Directory {
        Institute.Xcode.bundle(at: root.checkout)
    }

    /// Everything that must agree before a build can mean anything, or the
    /// reasons it does not.
    ///
    /// Every generated document and the typed materialization receipt are
    /// re-rendered from their current inputs and byte-compared. Staleness is
    /// refused rather than repaired: `workspace materialize` owns publication,
    /// and a build command that quietly regenerated its own inputs would be
    /// reporting on a workspace nobody asked for.
    ///
    /// The scheme check is the load-bearing one. `xcodebuild` silently drops
    /// a `BuildableReference` whose blueprint matches no target in its
    /// container — measured on this machine: one fabricated entry among valid
    /// ones exits 0 and prints `** BUILD SUCCEEDED **` having never built
    /// that package; only an entirely unmatched scheme fails, with exit 66.
    /// A manifest that renamed a target since the last `sync` therefore does
    /// not break the build, it shrinks it, and the shrunken build still looks
    /// green. Comparing the rendered scheme against the manifests before
    /// building is what makes that reachable.
    public func diagnostics() async throws(Institute.Error) -> [Swift.String] {
        try await preflight().diagnostics
    }

    /// The manifest read is one `swift package dump-package` per selected
    /// repository, so it happens once per command and both the gate and the
    /// reported target count are derived from that single read.
    private func preflight() async throws(Institute.Error) -> (
        plan: Institute.Xcode.Scheme.Plan,
        diagnostics: [Swift.String]
    ) {
        guard bundle[file: "contents.xcworkspacedata"].stat.exists else {
            return (
                .init(buildables: [], testables: []),
                ["\(Institute.Xcode.bundleName) is not generated; run `institute sync`"]
            )
        }

        let specification = try Institute.Xcode.integration(selection.repositories)
        var diagnostics = [Swift.String]()
        let catalog = try await Institute.Xcode.Acquisition.acquire(
            specification,
            at: root
        )
        let plan = try Institute.Xcode.Scheme.plan(for: specification, catalog: catalog)
        let prepared = try Institute.Xcode.Publication.plan(
            specification: specification,
            catalog: catalog,
            scheme: plan,
            at: root
        )
        if try !prepared.publication.current() {
            diagnostics.append(
                "generated workspace state and its materialization receipt do not match the "
                    + "selected packages' exact manifests (\(plan.buildables.count) buildable "
                    + "targets and \(plan.testables.count) testables); run "
                    + "`institute workspace materialize`."
                    + " An out-of-date scheme does not fail the build — it silently builds less"
                    + " of the selection."
            )
        }
        return (plan, diagnostics)
    }

    /// Runs the build and returns `xcodebuild`'s exit status.
    public func run(
        fresh: Swift.Bool,
        arguments: [Swift.String]
    ) async throws(Institute.Error) -> Swift.Int32 {
        try await run(
            fresh: fresh,
            arguments: arguments,
            capturingDiagnostics: false
        ).exitCode
    }

    /// Runs the build, optionally capturing `xcodebuild`'s `stdout`/`stderr`
    /// so a caller can extract the first compiler diagnostic mechanically —
    /// the ecosystem coherence instrument's `build`-stage attribution.
    public func run(
        fresh: Swift.Bool,
        arguments: [Swift.String],
        capturingDiagnostics: Swift.Bool
    ) async throws(Institute.Error) -> Institute_Model.Institute.Build.Coordinator.Result {
        let preflight = try await preflight()
        guard preflight.diagnostics.isEmpty else {
            throw .configuration(preflight.diagnostics.joined(separator: "\n"))
        }
        print(
            "build: \(selection.repositories.count) packages,"
                + " \(preflight.plan.buildables.count) targets, one xcodebuild invocation"
        )

        let operation = Institute_Model.Institute.Build.Workspace(
            bundle: bundle.description,
            scheme: Institute.Xcode.Scheme.name
        )
        do throws(Institute_Model.Institute.Build.Error) {
            return try Institute_Model.Institute.Build.Coordinator().run(
                operation,
                fresh: fresh,
                arguments: arguments,
                capturingDiagnostics: capturingDiagnostics
            )
        } catch {
            throw .process("\(error)")
        }
    }
}
