import Byte
import Environment
import File_System
public import Institute_Instruments
public import Institute_Model
import JSON

extension Institute.Certification.Command {
    /// Resolves the Institute root from the working directory.
    static func root() throws(Institute.Error) -> Institute.Root {
        guard let working = Environment.read("PWD") else {
            throw .configuration("PWD is not available")
        }
        let checkout: File.Directory
        do throws(File.Path.Error) {
            checkout = try File.Directory(validating: working)
        } catch {
            throw .configuration("Institute checkout is not a valid path: \(error)")
        }
        return try Institute.Root(checkout: checkout)
    }

    /// Reads one certification input file completely, as UTF-8 text.
    static func fileContents(
        atPath path: Swift.String,
        describedAs label: Swift.String
    ) throws(Institute.Error) -> Swift.String {
        let validated: File.Path
        do throws(File.Path.Error) {
            validated = try File.Path(path)
        } catch {
            throw .configuration("invalid \(label) path \(path): \(error)")
        }
        let bytes: [Byte]
        do throws(Either<File.System.Read.Full.Error, Never>) {
            bytes = try File.System.Read.Full.read(from: validated) {
                (span: Swift.Span<Byte>) in
                var storage = [Byte]()
                storage.reserveCapacity(span.count)
                for index in span.indices { storage.append(span[index]) }
                return storage
            }
        } catch {
            throw .configuration("cannot read \(label) at \(path): \(error)")
        }
        return Swift.String(decoding: bytes, as: Swift.UTF8.self)
    }

    /// Loads the frozen snapshot `certification run` and `certification
    /// assemble` evaluate — the `--receipt` input.
    static func snapshot(
        atPath path: Swift.String
    ) throws(Institute.Error) -> Institute.Certification.Snapshot {
        let text = try fileContents(atPath: path, describedAs: "--receipt")
        do {
            return try Institute.Certification.Snapshot(jsonString: text)
        } catch {
            throw .configuration("snapshot does not decode: \(error)")
        }
    }

    /// The platform this process evaluates as, for obligation derivation.
    static var platform: Institute.Certification.Platform {
        switch Institute.Coherence.Run.currentPlatform {
        case "macos": .macos
        case "windows": .windows
        default: .linux
        }
    }

    /// The canary policy `certification run` and `certification assemble`
    /// derive obligations under: the current platform, no quality gates.
    static func policy(
        platform: Institute.Certification.Platform
    ) throws(Institute.Error) -> Institute.Certification.Policy {
        do {
            return try .init(platforms: [platform], quality: [])
        } catch {
            throw .configuration("cannot form canary policy: \(error)")
        }
    }
}
