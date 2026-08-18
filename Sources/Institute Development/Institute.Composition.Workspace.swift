public import File_System
public import Institute_Model
private import Kernel
private import Synchronization

extension Institute.Composition {
    /// One location a composed build runs in: the generated-root
    /// directory, an isolated scratch directory, and an exclusive
    /// same-workspace execution lock.
    ///
    /// A workspace is addressed by ``key`` under a caller-supplied
    /// ``base`` — never derived from an absolute source path, so the
    /// same semantic inputs name the same workspace on every machine.
    /// The legacy shape — the generated root directly under the
    /// Institute checkout, where ``Institute/Composed/Root`` has always
    /// written it — is ``checkout(_:)``, whose container *is* the
    /// checkout; the coherence path keeps producing byte-identical
    /// locations through it.
    ///
    /// The lock guards workspace occupancy only. Running the actual
    /// SwiftPM build still goes through ``Build/Coordinator``'s one
    /// machine-wide coordination key; a second key for the same machine
    /// invariant would not compose, and this is deliberately a
    /// *different* invariant — two workspaces may hold their own locks
    /// concurrently, and the build coordinator serializes their builds.
    public struct Workspace: Swift.Equatable, Swift.Sendable {
        /// The directory owning this workspace's generated root and
        /// scratch state.
        public let container: File.Directory

        /// The directory manifest references resolve against — the
        /// Institute checkout whose hierarchy the composed sources live
        /// under. ``Institute/Composed/Root`` needs it to recompute a
        /// reference when the generated root does not sit at its legacy
        /// location directly under the checkout.
        public let anchor: File.Directory

        private init(container: File.Directory, anchor: File.Directory) {
            self.container = container
            self.anchor = anchor
        }
    }
}

extension Institute.Composition.Workspace {
    /// The legacy workspace: generated root and scratch directly under
    /// `checkout`, exactly where the coherence instrument has always
    /// written them.
    public static func checkout(_ checkout: File.Directory) -> Self {
        .init(container: checkout, anchor: checkout)
    }

    /// A keyed workspace under `base`, resolving manifest references
    /// against `anchor`.
    ///
    /// The container is `base/institute-composition-<key>`. `key` is a
    /// single path component derived by the caller from normalized
    /// semantic inputs and build arguments — never from an absolute
    /// source path.
    public static func keyed(
        _ key: File.Path.Component,
        under base: File.Directory,
        anchor: File.Directory
    ) -> Self {
        .init(
            container: base[directory: "institute-composition-\(key)"],
            anchor: anchor
        )
    }
}

extension Institute.Composition.Workspace {
    /// This workspace's generated composed root.
    public var generatedRoot: File.Directory {
        container[directory: Institute.Composed.Root.directoryName]
    }

    /// This workspace's isolated scratch directory for an ordinary run.
    public var scratch: File.Directory {
        container[directory: "institute-composition-scratch"]
    }

    /// The execution location of one run.
    ///
    /// An ordinary run reuses ``scratch``. A fresh run receives a fresh
    /// location — the first `institute-composition-scratch-fresh-<n>`
    /// not yet present under ``container`` — and never deletes any
    /// existing state: not a prior scratch, and never a source
    /// repository's resolution state, which no workspace location may
    /// ever contain.
    public func executionLocation(fresh: Swift.Bool) -> File.Directory {
        guard fresh else { return scratch }
        var n = 1
        while true {
            let candidate = container[directory: "institute-composition-scratch-fresh-\(n)"]
            guard candidate.stat.exists else { return candidate }
            n += 1
        }
    }
}

extension Institute.Composition.Workspace {
    /// The held execution lock of one workspace. Release is explicit;
    /// dropping the token without ``release()`` leaves the kernel lock
    /// to die with the descriptor at process exit, which is safe but
    /// reported as a leak by the acquiring test.
    public struct Token: ~Copyable {
        private let descriptor: File.Descriptor
        private let container: Swift.String

        fileprivate init(descriptor: consuming File.Descriptor, container: Swift.String) {
            self.descriptor = descriptor
            self.container = container
        }

        /// Releases the lock: the in-process claim first, then the
        /// kernel lock with the descriptor.
        public consuming func release() {
            Institute.Composition.Workspace.held.withLock { held in
                held.remove(container)
            }
            try? Kernel.Lock.unlock(descriptor.kernelDescriptor, range: .file)
            try? descriptor.close()
        }
    }

    /// The in-process occupancy claims, keyed by container path.
    ///
    /// POSIX record locks do not conflict within one process — a second
    /// `fcntl` lock over the same range in the same process silently
    /// coalesces — so same-process double acquisition must be refused
    /// here, before the kernel is asked.
    private static let held = Mutex<Swift.Set<Swift.String>>([])

    /// Acquires this workspace's exclusive execution lock without
    /// blocking. A workspace already held — by this process or any
    /// other — fails deterministically with a typed error.
    public func acquire() throws(Institute.Error) -> Token {
        do throws(File.System.Create.Directory.Error) {
            try container.create.recursive()
        } catch {
            throw .composition("cannot create the composition workspace \(container): \(error)")
        }

        let key = container.description
        let claimed = Self.held.withLock { held in
            held.insert(key).inserted
        }
        guard claimed else {
            throw .composition("composition workspace \(container) is already locked")
        }

        let descriptor: File.Descriptor
        do {
            descriptor = try File.Descriptor.open(
                container[file: "institute-composition.lock"].path,
                mode: .readWrite,
                options: [.create, .execClose]
            )
        } catch {
            _ = Self.held.withLock { held in held.remove(key) }
            throw .composition("cannot open the workspace lock in \(container): \(error)")
        }

        do throws(Kernel.Lock.Error) {
            try Kernel.Lock.Immediate.lock(
                descriptor.kernelDescriptor,
                range: .file,
                kind: .exclusive
            )
        } catch {
            _ = Self.held.withLock { held in held.remove(key) }
            try? descriptor.close()
            throw .composition("composition workspace \(container) is already locked: \(error)")
        }

        return .init(descriptor: descriptor, container: key)
    }
}
