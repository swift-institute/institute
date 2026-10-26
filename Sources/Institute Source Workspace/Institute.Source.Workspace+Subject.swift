internal import Byte
internal import FIPS_180_4
public import File_System
public import Git_Foundation
public import Institute_Model
internal import Institute_Source_Policy
internal import SPM_Standard
public import Source_Measurement

extension Institute.Source.Workspace {
    public static func subject(
        repository: Swift.String,
        revision: Swift.String,
        root: Swift.String,
        using git: Git.Client = .init()
    ) throws(Institute.Error) -> Source.Subject {
        let head: Swift.String
        let dirty: Swift.Bool
        do throws(Git.Client.Error) {
            head = try git.head(at: root).rawValue
            dirty = try !git.status(at: root).isEmpty
        } catch {
            throw .filesystem("cannot bind source package (repository): \(error)")
        }
        guard head == revision else {
            throw .configuration("source package HEAD is \(head), expected \(revision)")
        }
        guard !dirty else {
            throw .configuration("source package has changes outside revision \(revision)")
        }
        return try subject(identity: "\(repository)@\(revision)", root: root, using: git)
    }

    public static func subject(
        identity: Swift.String,
        root: Swift.String,
        using git: Git.Client = .init()
    ) throws(Institute.Error) -> Source.Subject {
        let paths: [Swift.String]
        do throws(Git.Client.Error) { paths = try git.paths(at: root) } catch {
            throw .filesystem("cannot enumerate Git paths for \(identity): \(error)")
        }
        return try subject(identity: identity, root: root, paths: paths)
    }

    public static func subject(
        identity: Swift.String,
        root rootPath: Swift.String,
        paths: [Swift.String]
    ) throws(Institute.Error) -> Source.Subject {
        let root: File.Directory
        do throws(File.Path.Error) { root = File.Directory(try .init(rootPath)) } catch {
            throw .configuration("invalid source member path \(rootPath)")
        }
        guard root[file: "Package.swift"].stat.isFile else {
            throw .configuration("source member manifest is missing at \(rootPath)")
        }
        let rootCanonical: File.Path
        do throws(File.System.Canonical.Error) {
            rootCanonical = try File.System.Canonical.resolve(root.path)
        } catch { throw .filesystem("cannot canonicalize source root \(rootPath): \(error)") }

        var sources: [Swift.String] = []
        var packages: [[Swift.Substring]] = []
        for path in paths where path.hasSuffix(".swift") {
            guard valid(path) else { throw .configuration("invalid source artifact path \(path)") }
            sources.append(path)
            // Only a real manifest makes a nested package: a production file named
            // Package.swift (a `Package` namespace, a fixture) stays a source, as it
            // does for SwiftPM and swift-linter.
            if path != "Package.swift", path.hasSuffix("/Package.swift"),
                try Package.Manifest.recognizes(bytes(of: path, under: root))
            {
                packages.append(Array(path.split(separator: "/").dropLast()))
            }
        }
        var candidates: Swift.Set<Swift.String> = ["Package.swift"]
        for path in sources
        where !packages.contains(where: { path.split(separator: "/").starts(with: $0) }) {
            candidates.insert(path)
        }
        let controls = Institute.Source.Policy.current.negativeControls(
            for: repository(of: identity)
        )
        // A declaration whose fixture is gone would leave its rule without a
        // control, so it is an error — once there are sources to look in. An
        // empty enumeration is a binding without sources (the target catalog's),
        // where nothing is missing.
        for path in controls.keys.sorted() where !paths.isEmpty && !candidates.contains(path) {
            throw .configuration("declared negative control is not a source artifact: \(path)")
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
                    purpose: controls[path].map {
                        .control(
                            .init(
                                identity: $0.identity,
                                predicate: $0.rule,
                                expectation: .findings($0.findings)
                            )
                        )
                    } ?? .governedSource,
                    provenance: .authored,
                    digest: try digest(file)
                )
            )
        }
        return .init(identity: identity, root: rootPath, artifacts: artifacts)
    }

    /// The `owner/name` a subject identity measures: a CI subject is named
    /// `repository@revision`.
    private static func repository(of identity: Swift.String) -> Swift.String {
        Swift.String(identity.prefix { $0 != "@" })
    }

    private static func bytes(
        of path: Swift.String,
        under root: File.Directory
    ) throws(Institute.Error) -> [Byte] {
        let parsed: File.Path
        do throws(File.Path.Error) { parsed = try .init(path) } catch {
            throw .configuration("invalid source artifact path \(path)")
        }
        let file = File(root.path / parsed)
        do throws(Either<File.System.Read.Full.Error, Never>) {
            return try file.read.full { span in
                var result: [Byte] = []
                result.reserveCapacity(span.count)
                for index in span.indices { result.append(span[index]) }
                return result
            }
        } catch { throw .filesystem("cannot read source artifact \(file): \(error)") }
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
