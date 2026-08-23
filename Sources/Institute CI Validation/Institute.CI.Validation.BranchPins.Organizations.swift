import struct Swift.String
public import Institute_Model
import File_System
public import Institute_CI_Model
import GitHub_Standard
public import Institute_CI_Workflow

extension Institute.CI.Validation.BranchPins {
    /// The Institute organization set, read from the canonical manifest.
    ///
    /// `[BRANCH-PIN-001]` is scoped to dependencies on *Institute* URLs,
    /// so the rule cannot be evaluated without knowing which GitHub
    /// organizations are the Institute's. The answer has exactly one
    /// owner — `.github/actions/read-orgs/orgs.yaml`, the manifest the
    /// cross-org sweeps enumerate from — and the retired validator went
    /// out of its way not to keep a second inline copy. Neither does
    /// this: the set is *read*, never spelled here, so recognition and
    /// enumeration cannot diverge.
    ///
    /// An archived organization is excluded, matching the `read-orgs`
    /// composite's own default. A record without a `status:` key is
    /// active.
    public struct Organizations: Sendable, Equatable {
        /// The manifest's canonical location inside a checkout of
        /// `swift-institute/.github`.
        public static let manifestPath = ".github/actions/read-orgs/orgs.yaml"

        public let names: Set<String>

        public init(names: Set<String>) {
            self.names = names
        }

        public func contains(_ name: String) -> Bool { names.contains(name) }

        /// Read the manifest at `path`.
        ///
        /// A manifest that is missing, unreadable, unparseable, or not a
        /// non-empty sequence is an `EnvironmentDefect`, not an empty
        /// set. An empty set would make every subject silently clean —
        /// the inert-gate failure mode this contract's exit-2 class
        /// exists to prevent, and the same choice the retired script
        /// made when it exited 2 on a malformed manifest.
        public static func read(
            at path: String
        ) throws(Institute.CI.Validation.EnvironmentDefect) -> Self {
            guard let text = Institute.CI.Validation.text(at: path) else {
                throw .missingSupportFile(path: path)
            }
            let node: Institute.CI.Workflow.YAML.Node
            do {
                node = try Institute.CI.Workflow.YAML.Parser.parse(text)
            } catch {
                throw .missingSupportFile(path: path)
            }
            guard let records = node.sequence, !records.isEmpty else {
                throw .missingSupportFile(path: path)
            }
            var names: Set<String> = []
            for record in records {
                guard let mapping = record.mapping,
                    let name = mapping["name"]?.text, !name.isEmpty,
                    mapping["status"]?.text != "archived"
                else { continue }
                names.insert(name)
            }
            guard !names.isEmpty else { throw .missingSupportFile(path: path) }
            return Self(names: names)
        }

        /// Find the manifest by walking up from `directory`.
        ///
        /// The retired script resolved its default manifest relative to
        /// its own source file; a compiled binary has no such anchor, so
        /// the equivalent is to look upward from the subject for the
        /// checkout that contains it. In every in-repository invocation
        /// — the fixture corpus above all — this resolves to the same
        /// file the script's `__file__`-relative default did.
        ///
        /// Invocations where the subject is a *foreign* checkout (the
        /// fleet sweep, the `swift-ci` guard) pass the manifest
        /// explicitly, exactly as they already pass `--orgs-file`.
        public static func locateManifest(startingAt directory: String) -> String? {
            guard var current = try? File.Path(directory) else { return nil }
            while true {
                guard let relative = try? File.Path(manifestPath) else { return nil }
                let candidate = current.appending(relative).description
                if Institute.CI.Validation.exists(candidate) { return candidate }
                guard let parent = current.parent,
                    parent.description != current.description
                else { return nil }
                current = parent
            }
        }
    }
}
