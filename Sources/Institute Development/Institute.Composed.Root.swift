public import Build_Coordinator
public import File_System
public import Institute_Inventory
public import Institute_Model

extension Institute.Composed {
    /// The generated composed root: one synthetic target,
    /// ``targetName``, depending on every library product of every
    /// contributing repository. Building it (`swift build`, no
    /// arguments) compiles the whole reachable composed closure once —
    /// the SwiftPM analogue of ``Xcode/Scheme``'s shared scheme.
    ///
    /// Unlike `institute.xcworkspace`/``Xcode/Scheme``, this directory is
    /// never detected-as-stale-and-refused: nothing else writes it
    /// between one coherence run's own write and that same run's build,
    /// so there is no window in which a persisted copy could go stale.
    /// ``write(_:swift:at:)`` regenerates it fresh at the start of every
    /// run instead.
    public enum Root {}
}

extension Institute.Composed.Root {
    /// The composed root's directory name, at the workspace checkout
    /// root — ignored, generated, never committed, exactly like
    /// `institute.xcworkspace`.
    public static let directoryName: File.Path.Component = "institute-composed-root"

    /// The composed root's one synthetic target and package name.
    public static let targetName: File.Path.Component = "CoherenceComposedRoot"

    public static func directory(in workspace: Institute.Composition.Workspace) -> File.Directory {
        workspace.generatedRoot
    }

    /// The legacy entry point, retained as a compatibility wrapper over
    /// the checkout-shaped ``Institute/Composition/Workspace`` and
    /// owning no behaviour of its own.
    @available(*, deprecated, message: "use directory(in:) with a Composition.Workspace")
    public static func directory(at checkout: File.Directory) -> File.Directory {
        directory(in: .checkout(checkout))
    }

    static func manifestFile(in workspace: Institute.Composition.Workspace) -> File {
        directory(in: workspace)[file: "Package.swift"]
    }

    static func sourceFile(in workspace: Institute.Composition.Workspace) -> File {
        directory(in: workspace)[directory: "Sources"][directory: targetName][file: "Root.swift"]
    }

    /// The repositories the composed root actually declares a
    /// dependency on — those exposing at least one library product —
    /// sorted by reference so the render is deterministic run over run
    /// on the same selection.
    static func contributing(
        _ manifests: [Institute.Composed.Manifest]
    ) -> [Institute.Composed
        .Manifest]
    {
        manifests.filter { !$0.libraryProducts.isEmpty }.sorted { $0.reference < $1.reference }
    }

    /// The whole composed reachable population: the buildable-target
    /// count of every contributing repository. See ``Composed``'s
    /// documentation for why a repository with no library product is
    /// excluded here rather than silently folded in.
    public static func expectedTargetCount(in manifests: [Institute.Composed.Manifest]) -> Swift.Int
    {
        contributing(manifests).reduce(0) { $0 + $1.buildableTargetCount }
    }

    /// The synthetic manifest's text.
    public static func render(
        _ manifests: [Institute.Composed.Manifest],
        swift: Swift.String
    )
        -> Swift.String
    {
        let selected = contributing(manifests)
        var lines = [Swift.String]()
        lines.append("// swift-tools-version: \(swift)")
        lines.append("")
        lines.append("import PackageDescription")
        lines.append("")
        lines.append("let package = Package(")
        lines.append("    name: \"\(targetName)\",")
        lines.append("    dependencies: [")
        for manifest in selected {
            lines.append("        .package(path: \"\(manifest.reference)\"),")
        }
        lines.append("    ],")
        lines.append("    targets: [")
        lines.append("        .target(")
        lines.append("            name: \"\(targetName)\",")
        lines.append("            dependencies: [")
        for manifest in selected {
            for product in manifest.libraryProducts {
                lines.append(
                    "                .product(name: \"\(product)\", package: \"\(manifest.package)\"),"
                )
            }
        }
        lines.append("            ]")
        lines.append("        )")
        lines.append("    ]")
        lines.append(")")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    /// `manifests` with every workspace-relative reference recomputed
    /// for `workspace`'s generated root.
    ///
    /// A reference is stored as `../<layout reference>`, correct exactly
    /// when the generated root sits directly under the checkout the
    /// reference was computed against. For the checkout-shaped
    /// workspace that is already true and every manifest passes through
    /// unchanged, byte for byte. For any other workspace each reference
    /// is resolved against the workspace ``Institute/Composition/Workspace/anchor``
    /// and re-expressed for the generated root — as a relative path when
    /// the source sits below the generated root (it ordinarily does
    /// not), and otherwise as the source's absolute path, which
    /// `.package(path:)` accepts. Deterministic relative rendering
    /// across roots is the build plan's task, not this one's.
    static func rebased(
        _ manifests: [Institute.Composed.Manifest],
        in workspace: Institute.Composition.Workspace
    ) -> [Institute.Composed.Manifest] {
        guard workspace.container != workspace.anchor else { return manifests }
        let root = directory(in: workspace)
        return manifests.map { manifest in
            var reference = manifest.reference
            if reference.hasPrefix("../") {
                let remainder = Swift.String(reference.dropFirst(3))
                if let path = try? File.Path(remainder) {
                    let absolute = workspace.anchor.path.appending(path)
                    reference = absolute.relative(to: root.path)?.description
                        ?? absolute.description
                }
            }
            return .init(
                reference: reference,
                package: manifest.package,
                libraryProducts: manifest.libraryProducts,
                buildableTargetCount: manifest.buildableTargetCount
            )
        }
    }

    /// The synthetic target's one source file. Its contents never depend
    /// on the selection — the composed graph is compiled through the
    /// manifest's declared product dependencies, not through anything
    /// this file imports or references — so it is written once per run
    /// unconditionally, exactly like the manifest.
    static let source = """
        // Generated by `institute coherence` for the swiftpm-composed-root
        // build path (swift-institute/institute-application#81). This file exists only
        // so \(targetName) is a valid SwiftPM target; the composed graph is
        // compiled through its declared product dependencies, not this
        // file's contents.

        """

    /// Writes the composed root fresh, replacing any prior generation.
    public static func write(
        _ manifests: [Institute.Composed.Manifest],
        swift: Swift.String,
        in workspace: Institute.Composition.Workspace
    ) throws(Institute.Error) {
        let root = directory(in: workspace)
        let rebased = rebased(manifests, in: workspace)
        do throws(File.System.Create.Directory.Error) {
            try root[directory: "Sources"][directory: targetName].create.recursive()
        } catch {
            throw .filesystem("cannot create \(root): \(error)")
        }
        do throws(File.System.Write.Atomic.Error) {
            try manifestFile(in: workspace).write.atomic(render(rebased, swift: swift))
        } catch {
            throw .filesystem("cannot write \(manifestFile(in: workspace)): \(error)")
        }
        do throws(File.System.Write.Atomic.Error) {
            try sourceFile(in: workspace).write.atomic(source)
        } catch {
            throw .filesystem("cannot write \(sourceFile(in: workspace)): \(error)")
        }
    }

    /// The legacy entry point, retained as a compatibility wrapper over
    /// the checkout-shaped workspace and owning no behaviour of its own.
    @available(*, deprecated, message: "use write(_:swift:in:) with a Composition.Workspace")
    public static func write(
        _ manifests: [Institute.Composed.Manifest],
        swift: Swift.String,
        at checkout: File.Directory
    ) throws(Institute.Error) {
        try write(manifests, swift: swift, in: .checkout(checkout))
    }
}

extension Institute.Composed.Root {
    /// Builds the composed root with `swift build`, optionally capturing
    /// diagnostics for the coherence instrument's mechanical attribution
    /// — the SwiftPM analogue of
    /// ``Xcode/Build/run(fresh:arguments:capturingDiagnostics:)``.
    public static func build(
        in workspace: Institute.Composition.Workspace,
        fresh: Swift.Bool,
        arguments: [Swift.String],
        capturingDiagnostics: Swift.Bool,
        coordinator: Build_Coordinator.Build.Coordinator = .init()
    ) throws(Institute.Error) -> Build_Coordinator.Build.Coordinator.Result {
        do throws(Build_Coordinator.Build.Error) {
            return try coordinator.run(
                .build,
                at: directory(in: workspace).description,
                fresh: fresh,
                arguments: arguments,
                capturingDiagnostics: capturingDiagnostics
            )
        } catch {
            throw .process("\(error)")
        }
    }

    /// The legacy entry point, retained as a compatibility wrapper over
    /// the checkout-shaped workspace and owning no behaviour of its own.
    @available(*, deprecated, message: "use build(in:fresh:arguments:capturingDiagnostics:coordinator:)")
    public static func build(
        at checkout: File.Directory,
        fresh: Swift.Bool,
        arguments: [Swift.String],
        capturingDiagnostics: Swift.Bool,
        coordinator: Build_Coordinator.Build.Coordinator = .init()
    ) throws(Institute.Error) -> Build_Coordinator.Build.Coordinator.Result {
        try build(
            in: .checkout(checkout),
            fresh: fresh,
            arguments: arguments,
            capturingDiagnostics: capturingDiagnostics,
            coordinator: coordinator
        )
    }
}
