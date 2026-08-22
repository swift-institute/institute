public import File_System
internal import Institute_Continuous_Integration
public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Source_Profile

extension Institute.Source.Acquisition {
  func acquire(
    _ asset: ContinuousIntegration.Source.Policy.Asset,
    executable: Swift.Bool,
    into directory: File.Directory
  ) async throws(Institute.Error) -> File {
    let component = try Self.component(asset.name)
    let destination = directory[file: component]
    if destination.stat.isFile,
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
      try await download(asset: asset, base: base, to: staging, under: directory)
    case .xcode(let application, let version, let build, let relativePath):
      try await copyXcode(
        application: application,
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
  private func download(
    asset: ContinuousIntegration.Source.Policy.Asset,
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
