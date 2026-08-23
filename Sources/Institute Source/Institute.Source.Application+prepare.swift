public import FIPS_180_4
public import File_System
public import Institute_Source_Policy
public import Institute_Model
internal import Institute_Source_Profile
public import Source_Profile
import Thread_Pool

extension Institute.Source.Application {
  public func prepare(
    workspace: Swift.String
  ) async throws(Institute.Error) -> Institute.Source.Preparation {
    let policy = Institute.Source.Policy.current
    let directory = try Self.artifactDirectory(workspace: workspace)
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Create.Directory.Error>) {
      try await directory.create.recursive()
    } catch {
      throw .filesystem("cannot create source profile directory \(directory): \(error)")
    }

    let tools = directory[directory: "tools"]
    let acquisition = Institute.Source.Acquisition(process: process)
    let swiftFormatAsset = try Self.engine("swift-format", policy: policy).executable
    let swiftLintAsset = try Self.engine("swiftlint", policy: policy).executable
    let linterAsset = try Self.engine("swift-linter", policy: policy).executable
    let swiftFormat = try await acquisition.acquire(swiftFormatAsset, executable: true, into: tools)
    let swiftLint = try await acquisition.acquire(swiftLintAsset, executable: true, into: tools)
    let linterToolFile = try await acquisition.acquire(linterAsset, executable: true, into: tools)
    let swiftFormatExecutable = swiftFormat.description
    let swiftLintExecutable = swiftLint.description
    let linterExecutable = linterToolFile.description
    let swiftFormatTool = swiftFormatAsset.digest
    let swiftLintTool = swiftLintAsset.digest
    let linterTool = linterAsset.digest
    let format = directory[file: try Self.component(policy.swiftFormat.path)]
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
      try await format.write.atomic(policy.swiftFormat.contents)
    } catch { throw .filesystem("cannot render \(format): \(error)") }
    let swiftLintConfiguration = directory[file: try Self.component(policy.swiftLint.path)]
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
      try await swiftLintConfiguration.write.atomic(policy.swiftLint.contents)
    } catch { throw .filesystem("cannot render \(swiftLintConfiguration): \(error)") }
    let swiftLintRules = try await Self.swiftLintRules(
      executable: swiftLintExecutable,
      configuration: swiftLintConfiguration.description,
      directory: directory.description,
      process: process
    )

    let instituteProfile = Institute.Source.Profile(policy: policy)
    var profiles: [Swift.String: Source_Profile.Source.Profile.Digest] = [:]
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
      profiles[bundle.rawValue] =
        policy.profile(
          swiftFormatExecutable: swiftFormatExecutable,
          swiftFormatTool: swiftFormatTool,
          swiftFormatConfigurationPath: format.description,
          swiftLintExecutable: swiftLintExecutable,
          swiftLintTool: swiftLintTool,
          swiftLintConfigurationPath: swiftLintConfiguration.description,
          swiftLintRules: swiftLintRules,
          linterExecutable: linterExecutable,
          linterTool: linterTool,
          linterConfigurationPath: linter.description,
          bundle: bundle,
          linterRules: rules
        ).digest
    }
    let preparation = Institute.Source.Preparation(
      policyRevision: policy.revision,
      swiftFormatExecutable: swiftFormatExecutable,
      swiftFormatTool: swiftFormatTool,
      swiftLintExecutable: swiftLintExecutable,
      swiftLintTool: swiftLintTool,
      swiftLintRules: swiftLintRules,
      linterExecutable: linterExecutable,
      linterTool: linterTool,
      directory: directory.description,
      profiles: profiles
    )
    let receipt = directory[file: "receipt.json"]
    do throws(Either<Kernel.Thread.Pool.Error, File.System.Write.Atomic.Error>) {
      try await receipt.write.atomic(preparation.jsonString(sortKeys: true) + "\n")
    } catch { throw .filesystem("cannot write source preparation receipt \(receipt): \(error)") }
    return preparation
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
