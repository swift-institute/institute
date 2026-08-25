public import File_System
public import Institute_Source_Policy
public import Institute_Model
public import Source_Profile
import Thread_Pool

extension Institute.Source.Acquisition {
  func snapshot(
    executable path: Swift.String,
    name: Swift.String,
    into directory: File.Directory
  ) throws(Institute.Error) -> (
    file: File,
    digest: Source_Profile.Source.Profile.Digest
  ) {
    let source: File
    do throws(File.Path.Error) { source = File(try .init(path)) } catch {
      throw .configuration("invalid local source tool path")
    }
    guard source.stat.isFile, !source.stat.isSymlink else {
      throw .configuration("local source tool is not a regular file")
    }
    let sourcePermissions: File.System.Metadata.Permissions
    do throws(Kernel.File.Stats.Error) { sourcePermissions = try source.stat.permissions } catch {
      throw .filesystem("cannot inspect local source tool permissions: \(error)")
    }
    guard
      sourcePermissions.contains(.ownerExecute)
        || sourcePermissions.contains(.groupExecute)
        || sourcePermissions.contains(.otherExecute)
    else {
      throw .configuration("local source tool is not executable")
    }

    let digest = try Institute.Source.Application.digest(file: source.description)
    let destination = directory[
      file: try Self.component("\(name)-local-\(digest.hex)")
    ]
    if destination.stat.isFile,
      try Institute.Source.Application.digest(file: destination.description) == digest
    {
      try Self.permissions(executable: true, file: destination)
      return (destination, digest)
    }

    do throws(File.System.Create.Directory.Error) {
      try File.System.Create.Directory.create(
        at: directory.path,
        createIntermediates: true
      )
    } catch {
      throw .filesystem("cannot create source asset directory \(directory): \(error)")
    }
    let stagingPath: File.Path
    do throws(File.Path.Temporary.Error) {
      stagingPath = try File.Path.Temporary.sibling(
        of: destination.path,
        prefix: ".source-local-linter-",
        suffix: ".staging"
      )
    } catch {
      throw .filesystem("cannot allocate local source tool staging path: \(error)")
    }
    let staging = File(stagingPath)
    defer {
      do throws(File.System.Delete.Error) {
        if staging.stat.exists { try staging.delete() }
      } catch {}
    }
    do throws(File.System.Copy.Error) {
      try File.System.Copy.copy(from: source.path, to: staging.path)
    } catch {
      throw .filesystem("cannot snapshot local source tool: \(error)")
    }
    let copied = try Institute.Source.Application.digest(file: staging.description)
    guard copied == digest else {
      throw .configuration("local source tool changed while being snapshotted")
    }
    try Self.permissions(executable: true, file: staging)
    do throws(File.System.Move.Error) {
      try File.System.Move.move(
        from: staging.path,
        to: destination.path,
        options: .init(overwrite: true)
      )
    } catch {
      throw .filesystem("cannot publish local source tool snapshot: \(error)")
    }
    return (destination, digest)
  }

  func acquire(
    _ asset: Institute.Source.Policy.Asset,
    executable: Swift.Bool,
    xcodeApplication: Swift.String? = nil,
    into directory: File.Directory
  ) async throws(Institute.Error) -> File {
    let component = try Self.component(asset.name)
    let destination = directory[file: component]
    if xcodeApplication == nil, destination.stat.isFile,
      try Institute.Source.Application.digest(file: destination.description) == asset.digest
    {
      try Self.permissions(executable: executable, file: destination)
      return destination
    }

    do throws(File.System.Create.Directory.Error) {
      try File.System.Create.Directory.create(
        at: directory.path,
        createIntermediates: true
      )
    } catch {
      throw .filesystem("cannot create source asset directory \(directory): \(error)")
    }
    let stagingPath: File.Path
    do throws(File.Path.Temporary.Error) {
      stagingPath = try File.Path.Temporary.sibling(
        of: destination.path,
        prefix: ".source-asset-",
        suffix: ".staging"
      )
    } catch {
      throw .filesystem("cannot allocate source asset staging path: \(error)")
    }
    let staging = File(stagingPath)
    defer {
      do throws(File.System.Delete.Error) {
        if staging.stat.exists { try staging.delete() }
      } catch {}
    }

    switch asset.origin {
    case .release(let base):
      guard xcodeApplication == nil else {
        throw .configuration("Xcode selection supplied for a release source asset")
      }
      try await download(asset: asset, base: base, to: staging, under: directory)
    case .releaseArchive(let base, let archive, let digest, let member):
      guard xcodeApplication == nil else {
        throw .configuration("Xcode selection supplied for an archive source asset")
      }
      try await extract(
        asset: asset,
        base: base,
        archive: archive,
        archiveDigest: digest,
        member: member,
        to: staging,
        under: directory
      )
    case .xcode(let application, let version, let build, let relativePath):
      try await copyXcode(
        application: xcodeApplication ?? application,
        version: version,
        build: build,
        relativePath: relativePath,
        to: staging,
        under: directory
      )
    }
    let actual = try Institute.Source.Application.digest(file: staging.description)
    guard actual == asset.digest else {
      throw .configuration(
        "source asset \(asset.name) hashes to \(actual.hex), expected \(asset.digest.hex)"
      )
    }
    try Self.permissions(executable: executable, file: staging)
    do throws(File.System.Move.Error) {
      try File.System.Move.move(
        from: staging.path,
        to: destination.path,
        options: .init(overwrite: true)
      )
    } catch {
      throw .filesystem("cannot publish verified source asset \(destination): \(error)")
    }
    return destination
  }
}

extension Institute.Source.Acquisition {
  private func extract(
    asset: Institute.Source.Policy.Asset,
    base: Swift.String,
    archive: Swift.String,
    archiveDigest: Source_Profile.Source.Profile.Digest,
    member: Swift.String,
    to destination: File,
    under directory: File.Directory
  ) async throws(Institute.Error) {
    guard !archive.isEmpty, !archive.contains("/"), !member.isEmpty, !member.contains("/")
    else { throw .configuration("source archive identity is not canonical") }
    let temporaryPath: File.Path
    do throws(File.Path.Temporary.Error) {
      temporaryPath = try File.Path.Temporary.sibling(
        of: destination.path,
        prefix: ".source-archive-",
        suffix: ".staged"
      )
    } catch { throw .filesystem("cannot allocate source archive directory: \(error)") }
    let temporary = File.Directory(temporaryPath)
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Create.Directory.Error>) {
      try await temporary.create.recursive()
    } catch {
      throw .filesystem("cannot create source archive directory: \(error)")
    }
    defer {
      do throws(File.System.Delete.Error) {
        if temporary.stat.exists { try temporary.delete.recursive() }
      } catch {}
    }
    let archiveFile = temporary[file: try Self.component(archive)]
    let archiveAsset = Institute.Source.Policy.Asset(
      name: archive,
      digest: archiveDigest,
      origin: .release(base: base)
    )
    try await download(asset: archiveAsset, base: base, to: archiveFile, under: directory)
    let actualArchive = try Institute.Source.Application.digest(file: archiveFile.description)
    guard actualArchive == archiveDigest else {
      throw .configuration(
        "source archive \(archive) hashes to \(actualArchive.hex), expected \(archiveDigest.hex)"
      )
    }
    let extracted = temporary[directory: "contents"]
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Create.Directory.Error>) {
      try await extracted.create.recursive()
    } catch {
      throw .filesystem("cannot create source archive extraction directory: \(error)")
    }
    let result = await process.run(
      "/usr/bin/ditto",
      ["-x", "-k", archiveFile.description, extracted.description],
      directory.description,
      [:]
    )
    let source = extracted[file: try Self.component(member)]
    guard result.status == 0, source.stat.isFile else {
      throw .process("cannot extract source asset \(asset.name): \(result.diagnostics)")
    }
    do throws(File.System.Copy.Error) {
      try File.System.Copy.copy(from: source.path, to: destination.path)
    } catch {
      throw .filesystem("cannot stage source archive member \(member): \(error)")
    }
  }

  private func download(
    asset: Institute.Source.Policy.Asset,
    base: Swift.String,
    to destination: File,
    under directory: File.Directory
  ) async throws(Institute.Error) {
    guard base.hasPrefix("https://"), !base.hasSuffix("/") else {
      throw .configuration("source asset release origin is not canonical: \(base)")
    }
    let result = await process.run(
      "/usr/bin/curl",
      [
        "--fail", "--silent", "--show-error", "--location", "--retry", "2",
        "--output", destination.description, "\(base)/\(asset.name)",
      ],
      directory.description,
      [:]
    )
    guard result.status == 0, destination.stat.isFile else {
      throw .process(
        "cannot acquire source asset \(asset.name): \(result.diagnostics)"
      )
    }
  }

  private func copyXcode(
    application: Swift.String,
    version: Swift.String,
    build: Swift.String,
    relativePath: Swift.String,
    to destination: File,
    under directory: File.Directory
  ) async throws(Institute.Error) {
    guard application.hasPrefix("/Applications/"), application.hasSuffix(".app"),
      !relativePath.hasPrefix("/"), !relativePath.split(separator: "/").contains("..")
    else { throw .configuration("invalid pinned Xcode source asset path") }
    let plist = "\(application)/Contents/version.plist"
    try await verifyPlist(
      key: "CFBundleShortVersionString",
      expected: version,
      plist: plist,
      under: directory
    )
    try await verifyPlist(
      key: "ProductBuildVersion",
      expected: build,
      plist: plist,
      under: directory
    )
    let source: File
    do throws(File.Path.Error) {
      source = File(try File.Path(application) / File.Path(relativePath))
    } catch { throw .configuration("invalid pinned Xcode source asset: \(error)") }
    guard source.stat.isFile else {
      throw .configuration("pinned Xcode source asset is missing: \(source)")
    }
    do throws(File.System.Copy.Error) {
      try File.System.Copy.copy(from: source.path, to: destination.path)
    } catch {
      throw .filesystem("cannot stage pinned Xcode source asset \(source): \(error)")
    }
  }

  private func verifyPlist(
    key: Swift.String,
    expected: Swift.String,
    plist: Swift.String,
    under directory: File.Directory
  ) async throws(Institute.Error) {
    let result = await process.run(
      "/usr/bin/plutil",
      ["-extract", key, "raw", "-o", "-", plist],
      directory.description,
      [:]
    )
    let values = result.output.split(whereSeparator: \.isWhitespace)
    guard result.status == 0, values.count == 1, values[0] == expected
    else {
      throw .configuration("pinned Xcode identity mismatch for \(key)")
    }
  }

  private static func component(_ name: Swift.String) throws(Institute.Error)
    -> File.Path.Component
  {
    guard !name.isEmpty, !name.contains("/"), name != ".", name != ".." else {
      throw .configuration("invalid source asset name \(name)")
    }
    do throws(File.Path.Component.Error) { return try .init(name) } catch {
      throw .configuration("invalid source asset name \(name): \(error)")
    }
  }

  private static func permissions(executable: Swift.Bool, file: File) throws(Institute.Error) {
    let permissions: File.System.Metadata.Permissions = executable ? .executable : .defaultFile
    do throws(File.System.Metadata.Permissions.Error) {
      try File.System.Metadata.Permissions.set(permissions, at: file.path)
    } catch { throw .filesystem("cannot set source asset permissions for \(file): \(error)") }
  }
}
