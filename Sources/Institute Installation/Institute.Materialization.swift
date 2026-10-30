public import File_System
public import Institute_Model
private import Kernel

extension Institute {
    /// The managed link-materialization contract.
    ///
    /// A materialization exposes canonical content at a second path
    /// without duplicating ownership: the context entry points,
    /// account-wide skill projections, and the installed `institute`
    /// command are all materializations of content that lives elsewhere.
    ///
    /// - POSIX: exactly a symbolic link whose stored text equals the
    ///   declared target. Nothing changed here.
    /// - Windows — PROVISIONAL, pending principal ratification
    ///   (fleet-green Windows-lane adjudication of 2026-08-17 on
    ///   swift-institute/.github#600): the contract is defined by its
    ///   observable outcome, not its mechanism. An entry satisfies it
    ///   when it resolves canonically to the same filesystem object as
    ///   the declared target — whatever reparse form produced that
    ///   (symbolic link or directory junction) — or when it is a
    ///   copy-materialization carrying ``markerName`` naming its
    ///   target. Directory junctions are the adjudicated preferred
    ///   mechanism for directory links (they need no privilege), but
    ///   the ecosystem's Windows substrate
    ///   (swift-microsoft/swift-windows-32) exposes no
    ///   junction-creation surface yet, so ``install(at:pointingTo:canonical:)``
    ///   attempts an unprivileged symbolic link first and falls back to
    ///   copy-materialization when link creation is not permitted.
    ///   A copy-materialization is verified by its marker, not by deep
    ///   content comparison; refreshing one means deleting it and
    ///   re-running the owning installer.
    public enum Materialization {}
}

extension Institute.Materialization {
    /// The verdict of ``verdict(at:expecting:canonical:)``.
    public enum Verdict: Equatable, Sendable {
        /// Nothing exists at the path.
        case missing

        /// The entry satisfies the materialization contract.
        case satisfied

        /// The entry is not a materialization at all (an unmanaged
        /// regular file or directory).
        case unmanaged

        /// The entry is a materialization of something other than the
        /// declared target.
        case divergent
    }

    /// The marker file naming the target of a copy-materialized
    /// directory (Windows fallback only).
    public static let markerName = ".institute-materialization"
}

extension Institute.Materialization {
    /// Materializes `canonical` at `path`.
    ///
    /// - Parameters:
    ///   - path: where the materialization is created.
    ///   - stored: the link text to store (may be relative; POSIX
    ///     stores it verbatim).
    ///   - canonical: the absolute path of the content being exposed,
    ///     used by the Windows copy fallback and never stored on POSIX.
    public static func install(
        at path: File.Path,
        pointingTo stored: File.Path,
        canonical: File.Path
    ) throws(Institute.Error) {
        do throws(File.System.Link.Symbolic.Error) {
            try File.System.Link.Symbolic.create(at: path, pointingTo: stored)
            return
        } catch {
            #if os(Windows)
                guard error.isPermissionDenied else {
                    throw .filesystem("cannot create symbolic link \(path): \(error)")
                }
            #else
                throw .filesystem("cannot create symbolic link \(path): \(error)")
            #endif
        }
        #if os(Windows)
            try copy(canonical, to: path)
        #endif
    }

    /// Judges the entry at `path` against the declared target.
    ///
    /// - Parameters:
    ///   - path: the materialization's path.
    ///   - stored: the exact link text expected on POSIX.
    ///   - canonical: the absolute path of the content the entry must
    ///     expose; the Windows contract compares against this.
    public static func verdict(
        at path: File.Path,
        expecting stored: File.Path,
        canonical: File.Path
    ) throws(Institute.Error) -> Verdict {
        guard let info = try metadata(at: path) else { return .missing }
        #if os(Windows)
            return try verdict(at: path, canonical: canonical, info: info)
        #else
            guard info.type == .symbolicLink else { return .unmanaged }
            guard try target(of: path) == stored else { return .divergent }
            return .satisfied
        #endif
    }
}

#if os(Windows)
    extension Institute.Materialization {
        private static func verdict(
            at path: File.Path,
            canonical: File.Path,
            info: File.System.Metadata.Info
        ) throws(Institute.Error) -> Verdict {
            // Mechanism-agnostic resolution equality: a symbolic link or
            // junction at `path` resolves to the target's own canonical
            // path; an unmanaged real entry resolves to itself.
            if let resolvedPath = resolve(path) {
                if let resolvedTarget = resolve(canonical), resolvedPath == resolvedTarget {
                    return .satisfied
                }
                // Distinguish a real entry (resolves to itself) from a
                // link form resolving elsewhere. A real entry's
                // resolution is its parent's resolution plus its own
                // name; a reparse form's is not.
                if let parent = path.parent,
                    let name = Array(path.components).last,
                    let resolvedParent = resolve(parent),
                    resolvedPath == resolvedParent / name
                {
                    return try copyVerdict(at: path, canonical: canonical, info: info)
                }
                return .divergent
            }
            // A real entry always resolves, so an unresolvable path is a
            // dangling link form — a materialization of something that
            // is not the declared target.
            return .divergent
        }

        /// The canonical resolution of `path`, or nil when it does not
        /// resolve (dangling link forms).
        private static func resolve(_ path: File.Path) -> File.Path? {
            do throws(File.System.Canonical.Error) {
                return try File.System.Canonical.resolve(path)
            } catch {
                return nil
            }
        }

        private static func copyVerdict(
            at path: File.Path,
            canonical: File.Path,
            info: File.System.Metadata.Info
        ) throws(Institute.Error) -> Verdict {
            switch info.type {
            case .directory:
                let component: File.Path.Component
                do throws(File.Path.Component.Error) {
                    component = try File.Path.Component(Self.markerName)
                } catch {
                    throw .configuration("invalid materialization marker name: \(error)")
                }
                let marker = File.Directory(path)[file: component]
                guard let markerInfo = try metadata(at: marker.path),
                    markerInfo.type == .regular
                else {
                    return .unmanaged
                }
                guard try read(marker) == canonical.description else {
                    return .divergent
                }
                return .satisfied

            case .regular:
                // A file copy-materialization matches its target's bytes.
                guard let targetInfo = try metadata(at: canonical),
                    targetInfo.type == .regular,
                    try read(File(path)) == read(File(canonical))
                else {
                    return .unmanaged
                }
                return .satisfied

            default:
                return .unmanaged
            }
        }

        private static func copy(
            _ canonical: File.Path,
            to path: File.Path
        ) throws(Institute.Error) {
            guard let info = try metadata(at: canonical) else {
                throw .filesystem(
                    "cannot materialize \(path): target \(canonical) does not exist"
                )
            }
            switch info.type {
            case .directory:
                do throws(File.System.Copy.Error) {
                    try File.System.Copy.recursive(from: canonical, to: path)
                } catch {
                    throw .filesystem("cannot copy-materialize \(path): \(error)")
                }
                let component: File.Path.Component
                do throws(File.Path.Component.Error) {
                    component = try File.Path.Component(Self.markerName)
                } catch {
                    throw .configuration("invalid materialization marker name: \(error)")
                }
                do throws(File.System.Write.Atomic.Error) {
                    try File.Directory(path)[file: component].write.atomic(
                        canonical.description
                    )
                } catch {
                    throw .filesystem(
                        "cannot write the materialization marker in \(path): \(error)"
                    )
                }

            case .regular:
                let contents = try read(File(canonical))
                do throws(File.System.Write.Atomic.Error) {
                    try File(path).write.atomic(contents)
                } catch {
                    throw .filesystem("cannot copy-materialize \(path): \(error)")
                }

            default:
                throw .filesystem(
                    "cannot materialize \(path): target \(canonical) is neither a "
                        + "regular file nor a directory"
                )
            }
        }
    }
#endif

extension Institute.Materialization {
    private static func metadata(
        at path: File.Path
    ) throws(Institute.Error) -> File.System.Metadata.Info? {
        do throws(Kernel.File.Stats.Error) {
            return try File.System.Stat.info(at: path, followSymlinks: false)
        } catch {
            if case .platform(let platform) = error, platform.code.isNotFound {
                return nil
            }
            throw .filesystem("cannot inspect \(path): \(error)")
        }
    }

    private static func target(of path: File.Path) throws(Institute.Error) -> File.Path {
        do throws(File.System.Link.Read.Target.Error) {
            return try File.System.Link.Read.Target.target(of: path)
        } catch {
            throw .filesystem("cannot read symbolic link \(path): \(error)")
        }
    }

    private static func read(_ file: File) throws(Institute.Error) -> Swift.String {
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try file.read.full { bytes in
                var storage = [Byte]()
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices {
                    storage.append(bytes[index])
                }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            throw .filesystem("cannot read \(file): \(error)")
        }
    }
}
