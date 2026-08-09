public import File_System
public import Git_Foundation
public import Institute_Model

extension Institute.Inventory {
  public struct Application<Content: Swift.Error>: Sendable {
    public let root: File.Directory
    public let policy: Institute.Inventory.Policy
    public let client: Institute.Inventory.Client<Content>
    public let git: Git.Client

    public init(
      root: File.Directory,
      policy: Institute.Inventory.Policy,
      client: Institute.Inventory.Client<Content>,
      git: Git.Client = .init()
    ) {
      self.root = root
      self.policy = policy
      self.client = client
      self.git = git
    }
  }
}

extension Institute.Inventory.Application {
  public func run(
    existing: Institute.Configuration.Document,
    dry: Bool
  ) async throws(Institute.Inventory.Error<Content>) -> Institute.Inventory.Writer.Plan {
    if !dry {
      try preflight()
    }
    let discovery = try await client.discover(policy)
    let configuration: Institute.Configuration
    do throws(Institute.Inventory.Merge.Error) {
      configuration = try Institute.Inventory.Merge()(
        discovery,
        into: existing.configuration
      )
    } catch {
      throw .merge(error)
    }

    do throws(Institute.Error) {
      let writer = Institute.Inventory.Writer(root: root)
      return try dry
        ? writer.plan(configuration)
        : writer.run(configuration, replacing: existing)
    } catch {
      throw .workspace(error)
    }
  }

  /// Refuses publication from a dirty or uninspectable Institute worktree.
  ///
  /// This runs before discovery, rather than after its hundreds of requests,
  /// so a command that cannot safely publish fails before paying for a live
  /// census. ``Institute/Inventory/Writer/run(_:replacing:)`` separately
  /// rejects a change to `Institute.json` that races discovery.
  private func preflight() throws(Institute.Inventory.Error<Content>) {
    let changes: [Git.Status.Entry]
    do throws(Git.Client.Error) {
      changes = try git.status(at: root.description)
    } catch {
      throw .workspace(
        .repository(
          "inventory regeneration cannot inspect the Institute worktree: \(error)"
        )
      )
    }

    guard changes.isEmpty else {
      throw .workspace(
        .repository(
          "inventory regeneration requires a clean Institute worktree; found "
            + "\(changes.count) changed path\(changes.count == 1 ? "" : "s")"
        )
      )
    }
  }
}
