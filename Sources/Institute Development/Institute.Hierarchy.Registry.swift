public import File_System
public import Institute_Inventory
public import Institute_Model
public import JSON

extension Institute.Hierarchy {
    /// The set of local hierarchies registered on this machine,
    /// persisted at the checkout root under
    /// `.workspace/hierarchies.json` — a sibling of the composition
    /// ledger at `.workspace/compositions.json`, following its persistence
    /// shape exactly: a schema ``version`` refused on mismatch, written
    /// pretty-printed with sorted keys and a trailing newline, and an
    /// absent file read as an empty registry rather than an error.
    ///
    /// This is checkout-local, per-machine state, never shared: which local
    /// roots happen to be registered *here, now*. It performs no filesystem
    /// search, no checkout deletion, and no Git worktree operation of any
    /// kind — it owns exactly the registry record.
    public struct Registry: Swift.Equatable, Swift.Sendable, JSON.Serializable {
        /// The registered hierarchies, in registration order.
        public let hierarchies: [Institute.Hierarchy]

        public init(hierarchies: [Institute.Hierarchy] = []) {
            self.hierarchies = hierarchies
        }
    }
}

extension Institute.Hierarchy.Registry {
    /// The schema version written to the registry. Bumped only on a
    /// breaking shape change; a mismatch is refused during decoding.
    internal static let version: Swift.Int = 1

    public static func serialize(_ value: Self) -> JSON {
        [
            "version": Self.version.json,
            "hierarchies": value.hierarchies.json,
        ]
    }

    public static func deserialize(_ json: JSON) throws(JSON.Error) -> Self {
        guard let object = json.dictionary else {
            throw .typeMismatch(expected: "object", got: "non-object")
        }
        guard let version = object["version"] else { throw .missingKey("version") }
        let number = try Swift.Int(json: version)
        guard number == Self.version else {
            throw .typeMismatch(
                expected: "hierarchy registry version \(Self.version)",
                got: Swift.String(number)
            )
        }
        guard let hierarchies = object["hierarchies"] else {
            throw .missingKey("hierarchies")
        }
        return try Self(hierarchies: [Institute.Hierarchy](json: hierarchies))
    }
}

extension Institute.Hierarchy.Registry {
    private static func file(at checkout: File.Directory) -> File {
        checkout[directory: ".workspace"][file: "hierarchies.json"]
    }

    /// Loads the registry at `checkout`, or the empty registry when the
    /// file is absent — the ordinary state of a workspace with no
    /// registered hierarchy.
    public static func load(
        at checkout: File.Directory
    ) throws(Institute.Hierarchy.Registry.Error) -> Self {
        let file = Self.file(at: checkout)
        guard file.stat.exists else { return .init() }

        let bytes: [Byte]
        do throws(Either<File.System.Read.Full.Error, Never>) {
            bytes = try file.read.full { span in
                var storage = [Byte]()
                storage.reserveCapacity(span.count)
                for index in span.indices {
                    storage.append(span[index])
                }
                return storage
            }
        } catch {
            throw .workspace(.filesystem("cannot read the hierarchy registry \(file): \(error)"))
        }

        do throws(JSON.Error) {
            return try .init(jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self))
        } catch {
            throw .workspace(
                .filesystem("cannot decode the hierarchy registry \(file): \(error)")
            )
        }
    }

    /// Writes the registry under `checkout`, creating `.workspace/` if
    /// needed.
    public func save(
        at checkout: File.Directory
    ) throws(Institute.Hierarchy.Registry.Error) {
        let container = checkout[directory: ".workspace"]
        do throws(File.System.Create.Directory.Error) {
            try container.create.recursive()
        } catch {
            throw .workspace(.filesystem("cannot create \(container): \(error)"))
        }

        let file = Institute.Hierarchy.Registry.file(at: checkout)
        do throws(File.System.Write.Atomic.Error) {
            try file.write.atomic(jsonString(pretty: true, sortKeys: true) + "\n")
        } catch {
            throw .workspace(
                .filesystem("cannot write the hierarchy registry \(file): \(error)")
            )
        }
    }
}

extension Institute.Hierarchy.Registry {
    /// Registers `id` at `locator` with `ownership`.
    ///
    /// Atomic: loads the current registry, validates, and writes the
    /// updated registry back within one call — there is no window in which
    /// a concurrent reader of this checkout observes a partially-applied
    /// registration.
    ///
    /// Refuses a duplicate id and refuses a locator that canonically
    /// resolves to the same physical directory as an already-registered
    /// hierarchy — canonicalized via ``File/System/Canonical/
    /// resolve(_:)`` so two different literal paths (a symlink alias, a
    /// relative spelling) naming the same directory still collide. An
    /// already-registered locator that no longer resolves at all cannot
    /// physically collide with the new one; that condition is reported by
    /// ``status(of:at:)``, not refused here.
    @discardableResult
    public static func register(
        id: Institute.Hierarchy.ID,
        locator: File.Directory,
        ownership: Institute.Hierarchy.Ownership,
        at checkout: File.Directory
    ) throws(Institute.Hierarchy.Registry.Error) -> Self {
        let registry = try Self.load(at: checkout)

        guard !registry.hierarchies.contains(where: { $0.id == id }) else {
            throw .duplicate(id)
        }

        let canonical: File.Path
        do throws(File.System.Canonical.Error) {
            canonical = try File.System.Canonical.resolve(locator.path)
        } catch {
            throw .workspace(
                .filesystem("cannot resolve hierarchy root \(locator): \(error)")
            )
        }

        for existing in registry.hierarchies {
            let existingCanonical: File.Path
            do throws(File.System.Canonical.Error) {
                existingCanonical = try File.System.Canonical.resolve(existing.locator.path)
            } catch {
                continue
            }
            guard existingCanonical != canonical else {
                throw .collision(existing: existing.id, requested: id)
            }
        }

        let updated = Self(
            hierarchies: registry.hierarchies + [
                Institute.Hierarchy(id: id, locator: locator, ownership: ownership)
            ]
        )
        try updated.save(at: checkout)
        return updated
    }

    /// The locator currently registered for `id`, exactly as stored.
    ///
    /// This revalidates only the registry record, not the filesystem — a
    /// locator whose root no longer exists is still returned here. Use
    /// ``status(of:at:)`` for the fail-closed physical check.
    public static func resolve(
        _ id: Institute.Hierarchy.ID,
        at checkout: File.Directory
    ) throws(Institute.Hierarchy.Registry.Error) -> File.Directory {
        let registry = try Self.load(at: checkout)
        guard let found = registry.hierarchies.first(where: { $0.id == id }) else {
            throw .notFound(id)
        }
        return found.locator
    }

    /// Every registered hierarchy, in registration order.
    public static func list(
        at checkout: File.Directory
    ) throws(Institute.Hierarchy.Registry.Error) -> [Institute.Hierarchy] {
        try Self.load(at: checkout).hierarchies
    }

    /// `id`'s current physical root, fail-closed.
    ///
    /// Canonicalizes the registered locator and confirms it is an existing
    /// directory. A root that cannot be resolved, or that is no longer a
    /// directory, is reported as ``Error/missing(_:)`` — never silently
    /// treated as valid.
    public static func status(
        of id: Institute.Hierarchy.ID,
        at checkout: File.Directory
    ) throws(Institute.Hierarchy.Registry.Error) -> File.Directory {
        let locator = try Self.resolve(id, at: checkout)

        let canonical: File.Path
        do throws(File.System.Canonical.Error) {
            canonical = try File.System.Canonical.resolve(locator.path)
        } catch {
            throw .missing(id)
        }

        let info: File.System.Metadata.Info
        do throws(Kernel.File.Stats.Error) {
            info = try File.System.Stat.info(at: canonical, followSymlinks: false)
        } catch {
            throw .missing(id)
        }
        guard info.type == .directory else {
            throw .missing(id)
        }

        return File.Directory(canonical)
    }

    /// Removes `id`'s registry record.
    ///
    /// This never touches the filesystem at the hierarchy's root —
    /// for either ``Institute/Hierarchy/Ownership`` case, the
    /// registry record is the only thing this ever deletes. No checkout
    /// deletion, and no Git worktree operation, happens here or anywhere in
    /// this type.
    @discardableResult
    public static func forget(
        _ id: Institute.Hierarchy.ID,
        at checkout: File.Directory
    ) throws(Institute.Hierarchy.Registry.Error) -> Self {
        let registry = try Self.load(at: checkout)
        guard registry.hierarchies.contains(where: { $0.id == id }) else {
            throw .notFound(id)
        }
        let updated = Self(
            hierarchies: registry.hierarchies.filter { $0.id != id }
        )
        try updated.save(at: checkout)
        return updated
    }
}
