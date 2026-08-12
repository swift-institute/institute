public import File_System
public import Institute_Inventory
public import Institute_Model
public import JSON

extension Institute.Materialization {
  /// The set of local materialisations registered on this machine,
  /// persisted at the checkout root under
  /// `.workspace/materializations.json` — a sibling of the composition
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
    /// The registered materialisations, in registration order.
    public let materializations: [Institute.Materialization]

    public init(materializations: [Institute.Materialization] = []) {
      self.materializations = materializations
    }
  }
}

extension Institute.Materialization.Registry {
  /// The schema version written to the registry. Bumped only on a
  /// breaking shape change; a mismatch is refused during decoding.
  internal static let version: Swift.Int = 1

  public static func serialize(_ value: Self) -> JSON {
    [
      "version": Self.version.json,
      "materializations": value.materializations.json,
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
        expected: "materialization registry version \(Self.version)",
        got: Swift.String(number)
      )
    }
    guard let materializations = object["materializations"] else {
      throw .missingKey("materializations")
    }
    return try Self(materializations: [Institute.Materialization](json: materializations))
  }
}

extension Institute.Materialization.Registry {
  private static func file(at checkout: File.Directory) -> File {
    checkout[directory: ".workspace"][file: "materializations.json"]
  }

  /// Loads the registry at `checkout`, or the empty registry when the
  /// file is absent — the ordinary state of a workspace with no
  /// registered materialisation.
  public static func load(
    at checkout: File.Directory
  ) throws(Institute.Materialization.Registry.Error) -> Self {
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
      throw .workspace(.filesystem("cannot read the materialization registry \(file): \(error)"))
    }

    do throws(JSON.Error) {
      return try .init(jsonString: Swift.String(decoding: bytes, as: Swift.UTF8.self))
    } catch {
      throw .workspace(
        .filesystem("cannot decode the materialization registry \(file): \(error)")
      )
    }
  }

  /// Writes the registry under `checkout`, creating `.workspace/` if
  /// needed.
  public func save(
    at checkout: File.Directory
  ) throws(Institute.Materialization.Registry.Error) {
    let container = checkout[directory: ".workspace"]
    do throws(File.System.Create.Directory.Error) {
      try container.create.recursive()
    } catch {
      throw .workspace(.filesystem("cannot create \(container): \(error)"))
    }

    let file = Institute.Materialization.Registry.file(at: checkout)
    do throws(File.System.Write.Atomic.Error) {
      try file.write.atomic(jsonString(pretty: true, sortKeys: true) + "\n")
    } catch {
      throw .workspace(
        .filesystem("cannot write the materialization registry \(file): \(error)")
      )
    }
  }
}

extension Institute.Materialization.Registry {
  /// Registers `id` at `locator` with `ownership`.
  ///
  /// Atomic: loads the current registry, validates, and writes the
  /// updated registry back within one call — there is no window in which
  /// a concurrent reader of this checkout observes a partially-applied
  /// registration.
  ///
  /// Refuses a duplicate id and refuses a locator that canonically
  /// resolves to the same physical directory as an already-registered
  /// materialisation — canonicalized via ``File/System/Canonical/
  /// resolve(_:)`` so two different literal paths (a symlink alias, a
  /// relative spelling) naming the same directory still collide. An
  /// already-registered locator that no longer resolves at all cannot
  /// physically collide with the new one; that condition is reported by
  /// ``status(of:at:)``, not refused here.
  @discardableResult
  public static func register(
    id: Institute.Materialization.ID,
    locator: File.Directory,
    ownership: Institute.Materialization.Ownership,
    at checkout: File.Directory
  ) throws(Institute.Materialization.Registry.Error) -> Self {
    let registry = try Self.load(at: checkout)

    guard !registry.materializations.contains(where: { $0.id == id }) else {
      throw .duplicate(id)
    }

    let canonical: File.Path
    do throws(File.System.Canonical.Error) {
      canonical = try File.System.Canonical.resolve(locator.path)
    } catch {
      throw .workspace(
        .filesystem("cannot resolve materialization root \(locator): \(error)")
      )
    }

    for existing in registry.materializations {
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
      materializations: registry.materializations + [
        Institute.Materialization(id: id, locator: locator, ownership: ownership)
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
    _ id: Institute.Materialization.ID,
    at checkout: File.Directory
  ) throws(Institute.Materialization.Registry.Error) -> File.Directory {
    let registry = try Self.load(at: checkout)
    guard let found = registry.materializations.first(where: { $0.id == id }) else {
      throw .notFound(id)
    }
    return found.locator
  }

  /// Every registered materialisation, in registration order.
  public static func list(
    at checkout: File.Directory
  ) throws(Institute.Materialization.Registry.Error) -> [Institute.Materialization] {
    try Self.load(at: checkout).materializations
  }

  /// `id`'s current physical root, fail-closed.
  ///
  /// Canonicalizes the registered locator and confirms it is an existing
  /// directory. A root that cannot be resolved, or that is no longer a
  /// directory, is reported as ``Error/missing(_:)`` — never silently
  /// treated as valid.
  public static func status(
    of id: Institute.Materialization.ID,
    at checkout: File.Directory
  ) throws(Institute.Materialization.Registry.Error) -> File.Directory {
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
  /// This never touches the filesystem at the materialisation's root —
  /// for either ``Institute/Materialization/Ownership`` case, the
  /// registry record is the only thing this ever deletes. No checkout
  /// deletion, and no Git worktree operation, happens here or anywhere in
  /// this type.
  @discardableResult
  public static func forget(
    _ id: Institute.Materialization.ID,
    at checkout: File.Directory
  ) throws(Institute.Materialization.Registry.Error) -> Self {
    let registry = try Self.load(at: checkout)
    guard registry.materializations.contains(where: { $0.id == id }) else {
      throw .notFound(id)
    }
    let updated = Self(
      materializations: registry.materializations.filter { $0.id != id }
    )
    try updated.save(at: checkout)
    return updated
  }
}
