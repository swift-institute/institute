public import File_System
public import Institute_Model
public import Source_Repair

extension Institute.Source.Application {
  public static func fileSystem(root: Swift.String) -> Source_Repair.Source.Repair.FileSystem {
    .init(
      exists: { relative in
        Self.file(relative, root: root)?.stat.exists == true
      },
      read: { relative in
        guard let file = Self.file(relative, root: root) else {
          return .failure(.init(code: "path-escape", detail: relative))
        }
        do throws(Either<File.System.Read.Full.Error, Never>) {
          return .success(
            try File.System.Read.Full.read(from: file.path) { span in
              var bytes: [UInt8] = []
              bytes.reserveCapacity(span.count)
              for index in span.indices { bytes.append(span[index].underlying) }
              return bytes
            }
          )
        } catch {
          return .failure(.init(code: "file-read", detail: "\(file): \(error)"))
        }
      },
      write: { relative, contents in
        guard let file = Self.file(relative, root: root) else {
          return .failure(.init(code: "path-escape", detail: relative))
        }
        do {
          if let parent = file.path.parent {
            try File.Directory(parent).create.recursive()
          }
          try file.write.atomic(contentsOf: contents.map(Byte.init))
          return .success(())
        } catch {
          return .failure(.init(code: "file-write", detail: "\(file): \(error)"))
        }
      },
      move: { from, to in
        guard let source = Self.file(from, root: root),
          let destination = Self.file(to, root: root)
        else { return .failure(.init(code: "path-escape", detail: "\(from) -> \(to)")) }
        do {
          if let parent = destination.path.parent {
            try File.Directory(parent).create.recursive()
          }
          try source.move.to(destination)
          return .success(())
        } catch {
          return .failure(.init(code: "file-move", detail: "\(from) -> \(to): \(error)"))
        }
      },
      delete: { relative in
        guard let file = Self.file(relative, root: root) else {
          return .failure(.init(code: "path-escape", detail: relative))
        }
        do {
          try file.delete()
          return .success(())
        } catch {
          return .failure(.init(code: "file-delete", detail: "\(file): \(error)"))
        }
      }
    )
  }

  private static func file(_ relative: Swift.String, root: Swift.String) -> File? {
    guard !relative.isEmpty, !relative.hasPrefix("/"),
      !relative.split(separator: "/").contains("..")
    else { return nil }
    do throws(File.Path.Error) {
      return File(try File.Path(root) / File.Path(relative))
    } catch { return nil }
  }
}
