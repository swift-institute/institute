extension Source.Repair {
  public struct Transaction: Sendable {
    public init() {}

    public func apply(_ members: [Member]) -> Result<Void, Source.Reason> {
      guard !members.isEmpty else {
        return .failure(.init(code: "empty-transaction", detail: "no repair subjects"))
      }
      var identities: Swift.Set<Swift.String> = []
      for member in members {
        guard identities.insert(member.subject.identity).inserted else {
          return .failure(.init(code: "duplicate-subject", detail: member.subject.identity))
        }
        if let reason = validate(member) { return .failure(reason) }
      }

      var journal: [(files: FileSystem, operation: Operation)] = []
      for member in members {
        for operation in member.plan.operations {
          switch publish(operation, files: member.files, journal: &journal) {
          case .success: break
          case .failure(let reason):
            return rollback(journal, after: reason)
          }
        }
      }
      for member in members {
        for postcondition in member.plan.postconditions {
          switch postcondition {
          case .file(let path, let expected):
            switch member.files.read(path) {
            case .success(let contents):
              guard digest(contents) == expected else {
                return rollback(
                  journal,
                  after: .init(
                    code: "postcondition",
                    detail: "digest mismatch at \(member.subject.identity):\(path)"
                  )
                )
              }
            case .failure(let reason): return rollback(journal, after: reason)
            }
          case .absent(let path):
            guard !member.files.exists(path) else {
              return rollback(
                journal,
                after: .init(
                  code: "postcondition",
                  detail: "file exists at \(member.subject.identity):\(path)"
                )
              )
            }
          }
        }
      }
      return .success(())
    }

    private func validate(_ member: Member) -> Source.Reason? {
      let plan = member.plan
      guard plan.subject == member.subject else {
        return .init(code: "stale-subject", detail: member.subject.identity)
      }
      guard plan.profile == member.profile else {
        return .init(code: "stale-profile", detail: member.profile.hex)
      }
      guard plan.sources == member.sources else {
        return .init(code: "stale-sources", detail: member.sources.hex)
      }
      guard plan.refusals.isEmpty else {
        return .init(code: "repair-refusal", detail: plan.refusals[0].reason.detail)
      }
      return validate(plan.operations)
    }

    private func publish(
      _ operation: Operation,
      files: FileSystem,
      journal: inout [(files: FileSystem, operation: Operation)]
    ) -> Result<Void, Source.Reason> {
      switch operation {
      case .rewrite(let path, let expected, let replacement):
        switch files.read(path) {
        case .failure(let reason): return .failure(reason)
        case .success(let original):
          guard digest(original) == expected else {
            return .failure(.init(code: "stale-file", detail: path))
          }
          switch files.write(path, replacement) {
          case .failure(let reason): return .failure(reason)
          case .success:
            journal.append(
              (
                files,
                .rewrite(
                  path: path,
                  expected: digest(replacement),
                  replacement: original
                )
              )
            )
            return .success(())
          }
        }

      case .create(let path, let contents):
        guard !files.exists(path) else {
          return .failure(.init(code: "create-collision", detail: path))
        }
        switch files.write(path, contents) {
        case .failure(let reason): return .failure(reason)
        case .success:
          journal.append((files, .delete(path: path, expected: digest(contents))))
          return .success(())
        }

      case .move(let from, let to, let expected):
        guard !files.exists(to) else {
          return .failure(.init(code: "move-collision", detail: to))
        }
        switch files.read(from) {
        case .failure(let reason): return .failure(reason)
        case .success(let contents):
          guard digest(contents) == expected else {
            return .failure(.init(code: "stale-file", detail: from))
          }
          switch files.move(from, to) {
          case .failure(let reason): return .failure(reason)
          case .success:
            journal.append((files, .move(from: to, to: from, expected: expected)))
            return .success(())
          }
        }

      case .delete(let path, let expected):
        switch files.read(path) {
        case .failure(let reason): return .failure(reason)
        case .success(let contents):
          guard digest(contents) == expected else {
            return .failure(.init(code: "stale-file", detail: path))
          }
          switch files.delete(path) {
          case .failure(let reason): return .failure(reason)
          case .success:
            journal.append((files, .create(path: path, contents: contents)))
            return .success(())
          }
        }
      }
    }

    private func rollback(
      _ journal: [(files: FileSystem, operation: Operation)],
      after reason: Source.Reason
    ) -> Result<Void, Source.Reason> {
      var ignored: [(files: FileSystem, operation: Operation)] = []
      for entry in journal.reversed() {
        if case .failure(let rollback) = publish(
          entry.operation,
          files: entry.files,
          journal: &ignored
        ) {
          return .failure(
            .init(
              code: "rollback",
              detail: "\(reason.detail); rollback: \(rollback.detail)"
            )
          )
        }
      }
      return .failure(reason)
    }

    private func validate(_ operations: [Operation]) -> Source.Reason? {
      var paths: Set<Swift.String> = []
      for operation in operations {
        let affected: [Swift.String]
        switch operation {
        case .rewrite(let path, _, _), .create(let path, _), .delete(let path, _):
          affected = [path]
        case .move(let from, let to, _): affected = [from, to]
        }
        for path in affected {
          guard !path.hasPrefix("/"),
            !path.split(separator: "/").contains("..")
          else {
            return .init(code: "path-escape", detail: path)
          }
          guard paths.insert(path).inserted else {
            return .init(code: "path-collision", detail: path)
          }
        }
      }
      return nil
    }

    private func digest(_ contents: [UInt8]) -> Swift.String {
      FIPS_180_4.SHA256.digest(contents.map(Byte.init)).hex
    }
  }
}
