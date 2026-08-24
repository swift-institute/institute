internal import Byte_Primitives
internal import FIPS_180_4
public import File_System
public import Git_Foundation
public import Institute_Model
public import Source_Measurement

extension Institute.Source.Workspace {
  public static func subject(
    for row: Row,
    using git: Git.Client = .init()
  ) throws(Institute.Error) -> Source.Subject {
    let paths: [Swift.String]
    do throws(Git.Client.Error) { paths = try git.paths(at: row.directory) } catch {
      throw .filesystem("cannot enumerate Git paths for \(row.identity): \(error)")
    }
    return try subject(for: row, paths: paths)
  }

  public static func subject(
    for row: Row,
    paths: [Swift.String]
  ) throws(Institute.Error) -> Source.Subject {
    let root: File.Directory
    do throws(File.Path.Error) { root = File.Directory(try .init(row.directory)) } catch {
      throw .configuration("invalid source member path \(row.directory)")
    }
    guard root[file: "Package.swift"].stat.isFile else {
      throw .configuration("source member manifest is missing at \(row.directory)")
    }
    let rootCanonical: File.Path
    do throws(File.System.Canonical.Error) {
      rootCanonical = try File.System.Canonical.resolve(root.path)
    } catch { throw .filesystem("cannot canonicalize source root \(row.directory): \(error)") }

    var sources: [Swift.String] = []
    var packages: [[Swift.Substring]] = []
    for path in paths where path.hasSuffix(".swift") {
      guard valid(path) else { throw .configuration("invalid source artifact path \(path)") }
      sources.append(path)
      if path != "Package.swift", path.hasSuffix("/Package.swift") {
        packages.append(Array(path.split(separator: "/").dropLast()))
      }
    }
    var candidates: Swift.Set<Swift.String> = ["Package.swift"]
    for path in sources
    where !packages.contains(where: { path.split(separator: "/").starts(with: $0) }) {
      candidates.insert(path)
    }
    var canonicalFiles: Swift.Set<Swift.String> = []
    var artifacts: [Source.Artifact] = []
    for path in candidates.sorted() {
      guard valid(path) else { throw .configuration("invalid source artifact path \(path)") }
      let parsed: File.Path
      do throws(File.Path.Error) { parsed = try .init(path) } catch {
        throw .configuration("invalid source artifact path \(path)")
      }
      let file = File(root.path / parsed)
      guard file.stat.isFile, !file.stat.isSymlink else {
        throw .filesystem("source artifact is missing or not a regular file: \(path)")
      }
      let canonical: File.Path
      do throws(File.System.Canonical.Error) {
        canonical = try File.System.Canonical.resolve(file.path)
      } catch { throw .filesystem("cannot canonicalize source artifact \(path): \(error)") }
      let rootComponents = Array(rootCanonical.components)
      let fileComponents = Array(canonical.components)
      guard fileComponents.count > rootComponents.count,
        fileComponents.prefix(rootComponents.count).elementsEqual(rootComponents)
      else { throw .configuration("source artifact escapes workspace member: \(path)") }
      guard canonicalFiles.insert(canonical.description).inserted else {
        throw .configuration("duplicate canonical source artifact: \(path)")
      }
      artifacts.append(
        .init(
          path: path,
          kind: .swift,
          purpose: .governedSource,
          provenance: .authored,
          digest: try digest(file)
        )
      )
    }
    return .init(identity: row.identity, root: row.directory, artifacts: artifacts)
  }

  private static func digest(_ file: File) throws(Institute.Error) -> Source.Artifact.Digest {
    let bytes: [Byte]
    do throws(Either<File.System.Read.Full.Error, Never>) {
      bytes = try file.read.full { span in
        var result: [Byte] = []
        result.reserveCapacity(span.count)
        for index in span.indices { result.append(span[index]) }
        return result
      }
    } catch { throw .filesystem("cannot read source artifact \(file): \(error)") }
    return .init(FIPS_180_4.SHA256.digest(bytes).hex)
  }

  private static func valid(_ path: Swift.String) -> Swift.Bool {
    guard !path.isEmpty, !path.hasPrefix("/") else { return false }
    let components = path.split(separator: "/", omittingEmptySubsequences: false)
    return !components.contains { $0.isEmpty || $0 == "." || $0 == ".." }
  }
}
