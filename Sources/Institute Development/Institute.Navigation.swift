public import File_System
public import Git_Foundation
public import Institute_Inventory
public import Institute_Model

extension Institute {
    /// Reproducible local tooling for cclsp-backed Swift navigation.
    ///
    /// cclsp remains a third-party TypeScript tool. Institute owns only the
    /// installation boundary, generated configuration, and SourceKit-LSP
    /// launch policy needed to use that tool against this checkout.
    public struct Navigation: Sendable {
        public let root: Institute.Root
        public let configuration: Institute.Configuration
        public let client: Git.Client

        public init(
            root: Institute.Root,
            configuration: Institute.Configuration,
            client: Git.Client = .init()
        ) {
            self.root = root
            self.configuration = configuration
            self.client = client
        }
    }
}

extension Institute.Navigation {
    /// Public fork containing the SourceKit-LSP adapter and byte-framing fix.
    public static let repository =
        "https://github.com/swift-institute/cclsp.git"

    /// Published development line carrying the Institute integration.
    public static let branch = "sourcekit-lsp-adapter"

    /// Exact source revision used by generated navigation state.
    public static let revision =
        "155344c587d9a94dee8edb36fbb2b31693930b22"

    static let revisionComponent: File.Path.Component =
        "155344c587d9a94dee8edb36fbb2b31693930b22"

    static let installedBranch = "workspace-pinned"

    public var state: File.Directory {
        root.hierarchy[directory: ".workspace"][directory: "navigation"]
    }

    public var tools: File.Directory {
        root.hierarchy[directory: ".workspace"][directory: "tools"]
    }

    public var source: File.Directory {
        tools[directory: "cclsp"][directory: Self.revisionComponent]
    }

    public var executable: File {
        source[directory: "dist"][file: "index.js"]
    }

    public var configurationFile: File {
        state[file: "cclsp.json"]
    }

    public var descriptorFile: File {
        state[file: "mcp-server.json"]
    }

    public var workspaceExecutable: File {
        root.checkout[directory: ".build"][directory: "debug"][file: "institute"]
    }
}

extension Institute.Navigation {
    /// The first line of a tool's output, without the trailing newline —
    /// the shape `xcode-select --print-path`, `xcrun --find` and
    /// `node --version` report.
    ///
    /// Development keeps its own, exactly as `Institute.Coherence.Run`,
    /// `Institute.Conversion.Seal`, `Institute.Pages` and
    /// `Institute.Verification.Environment` each already do. Until the
    /// target split this reached across the single compile unit into
    /// `Institute.Doctor.line`, an internal helper of the Doctor target
    /// that carries no doctoring meaning — the only edge that made
    /// Development and Doctor mutually referential (Amendment 6 partition
    /// supplement, clause 3). Doctor measures what Development writes, so
    /// Doctor is the side that may depend on Development; the borrowed
    /// helper was the misplaced concern and it now sits where it is used.
    static func line(_ output: Swift.String) -> Swift.String {
        output.split(separator: "\n", omittingEmptySubsequences: true)
            .first
            .map(Swift.String.init) ?? ""
    }
}
