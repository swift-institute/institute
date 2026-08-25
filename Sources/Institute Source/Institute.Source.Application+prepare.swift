public import FIPS_180_4
public import File_System
public import Institute_Source_Policy
public import Institute_Model
internal import Institute_Source_Profile
public import Source_Profile
public import Source_Repair
import Thread_Pool

extension Institute.Source.Application {
  public enum Executable: Sendable, Equatable {
    case published
    case local(executable: Swift.String)
  }

  public func prepare(
    workspace: Swift.String,
    xcodeApplication: Swift.String? = nil,
    swiftLint swiftLintSelection: Executable = .published,
    linter linterSelection: Executable = .published
  ) async throws(Institute.Error) -> Institute.Source.Preparation {
    try await prepare(
      directory: Self.artifactDirectory(workspace: workspace),
      binding: .workspace(
        digest: try Self.digest(file: workspace + "/contents.xcworkspacedata").hex
      ),
      xcodeApplication: xcodeApplication,
      swiftLint: swiftLintSelection,
      linter: linterSelection
    )
  }

  public func prepare(
    subject: Source_Repair.Source.Subject,
    xcodeApplication: Swift.String? = nil,
    swiftLint swiftLintSelection: Executable = .published,
    linter linterSelection: Executable = .published
  ) async throws(Institute.Error) -> Institute.Source.Preparation {
    try await prepare(
      directory: try Self.artifactDirectory(packageRoot: subject.root),
      binding: .package(subject.binding),
      xcodeApplication: xcodeApplication,
      swiftLint: swiftLintSelection,
      linter: linterSelection
    )
  }

  private func prepare(
    directory: File.Directory,
    binding: Institute.Source.Preparation.Binding,
    xcodeApplication: Swift.String?,
    swiftLint swiftLintSelection: Executable,
    linter linterSelection: Executable
  ) async throws(Institute.Error) -> Institute.Source.Preparation {
    let policy = Institute.Source.Policy.current
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Create.Directory.Error>) {
      try await directory.create.recursive()
    } catch {
      throw .filesystem("cannot create source profile directory \(directory): \(error)")
    }

    let tools = directory[directory: "tools"]
    let acquisition = Institute.Source.Acquisition(process: process)
    let swiftFormatAsset = try Self.engine("swift-format", policy: policy).executable
    let swiftFormat = try await acquisition.acquire(
      swiftFormatAsset,
      executable: true,
      xcodeApplication: xcodeApplication,
      into: tools
    )
    let swiftLintToolFile: File
    let swiftLint: Institute.Source.Preparation.Tool
    switch swiftLintSelection {
    case .published:
      let asset = try Self.engine("swiftlint", policy: policy).executable
      swiftLintToolFile = try await acquisition.acquire(asset, executable: true, into: tools)
      swiftLint = .init(origin: .published(asset: asset.name), digest: asset.digest)
    case .local(let executable):
      let snapshot = try acquisition.snapshot(
        executable: executable,
        name: "swiftlint",
        into: tools
      )
      swiftLintToolFile = snapshot.file
      swiftLint = .init(origin: .local, digest: snapshot.digest)
    }
    let linterToolFile: File
    let linter: Institute.Source.Preparation.Tool
    switch linterSelection {
    case .published:
      let asset = try Self.engine("swift-linter", policy: policy).executable
      linterToolFile = try await acquisition.acquire(asset, executable: true, into: tools)
      linter = .init(origin: .published(asset: asset.name), digest: asset.digest)
    case .local(let executable):
      let snapshot = try acquisition.snapshot(
        executable: executable,
        name: "swift-linter",
        into: tools
      )
      linterToolFile = snapshot.file
      linter = .init(origin: .local, digest: snapshot.digest)
    }
    let swiftFormatExecutable = swiftFormat.description
    let swiftLintExecutable = swiftLintToolFile.description
    let linterExecutable = linterToolFile.description
    let swiftFormatTool = swiftFormatAsset.digest
    let swiftLintTool = swiftLint.digest
    let linterTool = linter.digest
    let format = directory[file: try Self.component(policy.swiftFormat.path)]
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
      try await format.write.atomic(policy.swiftFormat.contents)
    } catch { throw .filesystem("cannot render \(format): \(error)") }
    let formatRepair = directory[file: try Self.component(policy.swiftFormatRepair.path)]
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
      try await formatRepair.write.atomic(policy.swiftFormatRepair.contents)
    } catch { throw .filesystem("cannot render \(formatRepair): \(error)") }
    let swiftLintConfiguration = directory[file: try Self.component(policy.swiftLint.path)]
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
      try await swiftLintConfiguration.write.atomic(policy.swiftLint.contents)
    } catch { throw .filesystem("cannot render \(swiftLintConfiguration): \(error)") }

    let instituteProfile = Institute.Source.Profile(policy: policy)
    var profiles: [Swift.String: Source_Profile.Source.Profile.Digest] = [:]
    var verifiedProfiles: [Swift.String] = []
    for bundle in policy.bundles {
      let rules = instituteProfile.rules(for: bundle)
      let artifact = policy.linter(bundle: bundle, rules: rules)
      let linter = directory[
        file: try Self.component("\(bundle.rawValue)-\(artifact.path)")
      ]
      do throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
        try await linter.write.atomic(artifact.contents)
      } catch
      { throw .filesystem("cannot render \(linter): \(error)") }
      try await Self.verify(
        profile: linter.description,
        bundle: bundle,
        linterExecutable: linterExecutable,
        directory: directory.description,
        process: process
      )
      verifiedProfiles.append(bundle.rawValue)
      profiles[bundle.rawValue] =
        policy.profile(
          swiftFormatExecutable: swiftFormatExecutable,
          swiftFormatTool: swiftFormatTool,
          swiftFormatConfigurationPath: format.description,
          swiftLintExecutable: swiftLintExecutable,
          swiftLintTool: swiftLintTool,
          swiftLintConfigurationPath: swiftLintConfiguration.description,
          linterExecutable: linterExecutable,
          linterTool: linterTool,
          linterConfigurationPath: linter.description,
          bundle: bundle,
          linterRules: rules
        ).digest
    }
    let preparation = Institute.Source.Preparation(
      policyRevision: policy.revision,
      binding: binding,
      swiftFormatExecutable: swiftFormatExecutable,
      swiftFormatTool: swiftFormatTool,
      swiftLintExecutable: swiftLintExecutable,
      swiftLint: swiftLint,
      linterExecutable: linterExecutable,
      linter: linter,
      directory: directory.description,
      profiles: profiles,
      verifiedProfiles: verifiedProfiles.sorted()
    )
    let receipt = directory[file: "receipt.json"]
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
      try await receipt.write.atomic(preparation.jsonString(sortKeys: true) + "\n")
    } catch { throw .filesystem("cannot write source preparation receipt \(receipt): \(error)") }
    return preparation
  }

  static func verify(
    profile: Swift.String,
    bundle: Institute.Source.Bundle,
    linterExecutable: Swift.String,
    directory: Swift.String,
    process: Source_Profile.Source.Engine.Process
  ) async throws(Institute.Error) {
    let result = await process.run(
      linterExecutable,
      ["--profile-check", profile],
      directory,
      ["SWIFT_LINTER_BUNDLE": bundle.token]
    )
    guard result.status == 0 else {
      throw .configuration(
        "rendered source linter profile for \(bundle.rawValue) does not parse "
          + "under the pinned engine: \(result.diagnostics)\(result.output)"
      )
    }
  }

  private static func engine(
    _ token: Swift.String,
    policy: Institute.Source.Policy
  ) throws(Institute.Error) -> Institute.Source.Policy.Engine {
    let matches = policy.engines.filter {
      $0.id.token == token && $0.platform.token == "macos-arm64"
    }
    guard matches.count == 1, let engine = matches.first else {
      throw .configuration("source policy must declare exactly one macos-arm64 \(token) engine")
    }
    return engine
  }

  public static func artifactDirectory(workspace: Swift.String) throws(Institute.Error)
    -> File.Directory
  {
    let path: File.Path
    do throws(File.Path.Error) { path = try .init(workspace) } catch {
      throw .configuration("invalid source workspace path \(workspace)")
    }
    guard let parent = File.Directory(path).parent else {
      throw .configuration("source workspace has no containing directory")
    }
    return parent[directory: ".source"]
  }

  public static func artifactDirectory(packageRoot: Swift.String) throws(Institute.Error)
    -> File.Directory
  {
    let path: File.Path
    do throws(File.Path.Error) { path = try .init(packageRoot) } catch {
      throw .configuration("invalid source package path \(packageRoot)")
    }
    let root = File.Directory(path)
    guard root[file: "Package.swift"].stat.isFile else {
      throw .configuration("source package manifest is missing at \(packageRoot)")
    }
    return root[directory: ".source"]
  }

  static func digest(file path: Swift.String) throws(Institute.Error)
    -> Source_Profile.Source.Profile.Digest
  {
    let file: File
    do throws(File.Path.Error) { file = File(try .init(path)) } catch {
      throw .configuration("invalid tool path \(path)")
    }
    let bytes: [Byte]
    do throws(Either<File.System.Read.Full.Error, Never>) {
      bytes = try File.System.Read.Full.read(from: file.path) { span in
        var result: [Byte] = []
        result.reserveCapacity(span.count)
        for index in span.indices { result.append(span[index]) }
        return result
      }
    } catch { throw .filesystem("cannot read source tool \(path): \(error)") }
    return .init(FIPS_180_4.SHA256.digest(bytes).hex)
  }

  static func matches(
    file path: Swift.String,
    digest expected: Source_Profile.Source.Profile.Digest
  ) -> Swift.Bool {
    do throws(Institute.Error) { return try Self.digest(file: path) == expected } catch {
      return false
    }
  }

  private static func component(_ name: Swift.String) throws(Institute.Error)
    -> File.Path.Component
  {
    do throws(File.Path.Component.Error) { return try .init(name) } catch {
      throw .configuration("invalid source preparation artifact name \(name): \(error)")
    }
  }
}
