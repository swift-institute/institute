public import File_System
public import FIPS_180_4
public import Institute_Continuous_Integration_Source
public import Institute_Model
public import Source_Profile

extension Institute.Source.Application {
    public func prepare(
        workspace: Swift.String,
        swiftFormatExecutable: Swift.String,
        linterExecutable: Swift.String
    ) throws(Institute.Error) -> Institute.Source.Preparation {
        let policy = Institute.ContinuousIntegration.Source.Policy.current
        let directory = try Self.artifactDirectory(workspace: workspace)
        do throws(File.System.Create.Directory.Error) { try directory.create.recursive() }
        catch { throw .filesystem("cannot create source profile directory \(directory): \(error)") }

        let swiftFormatTool = try Self.digest(file: swiftFormatExecutable)
        let linterTool = try Self.digest(file: linterExecutable)
        let format = directory[file: policy.swiftFormat.path]
        do throws(File.System.Write.Atomic.Error) { try format.write.atomic(policy.swiftFormat.contents) }
        catch { throw .filesystem("cannot render \(format): \(error)") }

        let instituteProfile = Institute.Source.Profile(policy: policy)
        var profiles: [Swift.String: SourceDomain.Profile.Digest] = [:]
        for bundle in policy.bundles {
            let rules = instituteProfile.rules(for: bundle)
            let artifact = policy.linter(bundle: bundle, rules: rules)
            let linter = directory[file: "\(bundle.rawValue)-\(artifact.path)"]
            do throws(File.System.Write.Atomic.Error) { try linter.write.atomic(artifact.contents) }
            catch { throw .filesystem("cannot render \(linter): \(error)") }
            profiles[bundle.rawValue] = policy.profile(
                swiftFormatExecutable: swiftFormatExecutable,
                swiftFormatTool: swiftFormatTool,
                swiftFormatConfigurationPath: format.description,
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
            linterExecutable: linterExecutable,
            linterTool: linterTool,
            directory: directory.description,
            profiles: profiles
        )
        let receipt = directory[file: "receipt.json"]
        do throws(File.System.Write.Atomic.Error) {
            try receipt.write.atomic(preparation.jsonString(sortKeys: true) + "\n")
        } catch { throw .filesystem("cannot write source preparation receipt \(receipt): \(error)") }
        return preparation
    }

    static func artifactDirectory(workspace: Swift.String) throws(Institute.Error) -> File.Directory {
        let path: File.Path
        do throws(File.Path.Error) { path = try .init(workspace) }
        catch { throw .configuration("invalid source workspace path \(workspace)") }
        guard let parent = File.Directory(path).parent else {
            throw .configuration("source workspace has no containing directory")
        }
        return parent[directory: ".source"]
    }

    static func digest(file path: Swift.String) throws(Institute.Error) -> SourceDomain.Profile.Digest {
        let file: File
        do throws(File.Path.Error) { file = File(try .init(path)) }
        catch { throw .configuration("invalid tool path \(path)") }
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
}
