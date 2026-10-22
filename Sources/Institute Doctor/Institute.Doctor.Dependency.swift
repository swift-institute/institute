public import Byte
public import File_System
public import Institute_Development
public import Institute_Inventory
public import Institute_Model
public import Institute_Pages
public import SPM_Standard

extension Institute.Doctor {
    /// One direct URL dependency and the Institute package, if any, whose
    /// SwiftPM identity has the same last path component.
    public struct Dependency: Equatable, Sendable {
        public let repository: Swift.String
        public let line: Swift.Int
        public let url: Swift.String
        public let institute: [Swift.String]

        public init(
            repository: Swift.String,
            line: Swift.Int,
            url: Swift.String,
            institute: [Swift.String]
        ) {
            self.repository = repository
            self.line = line
            self.url = url
            self.institute = institute
        }
    }
}

extension Institute.Doctor {
    /// A third-party package may not claim the identity of an Institute
    /// package. The Institute package keeps its chosen name; the dependency
    /// graph must remove or replace the third-party claimant.
    public static let dependency = Check<Dependency>(
        name: "package-identity-clash",
        scope: .contributor,
        controls: .init(
            positive: .init(
                repository: "control",
                line: 1,
                url: "https://github.com/vendor/swift-control.git",
                institute: ["https://github.com/swift-atoms/swift-control.git"]
            ),
            negative: .init(
                repository: "control",
                line: 1,
                url: "https://github.com/swift-atoms/swift-control.git",
                institute: ["https://github.com/swift-atoms/swift-control.git"]
            )
        )
    ) { dependency in
        guard !dependency.institute.isEmpty, !dependency.institute.contains(dependency.url) else {
            return []
        }
        return [
            .init(
                severity: .error,
                message:
                    "\(dependency.repository)/Package.swift:\(dependency.line): "
                    + "\(dependency.url) clashes with Institute package "
                    + dependency.institute.joined(separator: ", ") + "; "
                    + "keep the Institute package name and replace or remove the third-party dependency"
            )
        ]
    }

    /// Parses one manifest with Swift syntax awareness. Line and block
    /// comments are excluded by the parser, while `//` inside a URL string is
    /// preserved as string contents.
    public static func dependencies(
        repository: Swift.String,
        source: Swift.String,
        institute: [Swift.String: [Swift.String]]
    ) throws(Package.Dependency.Declaration.Parser.Error) -> [Dependency] {
        try Package.Dependency.Declaration.Parser().parse([Byte](utf8: source)).compactMap {
            declaration in
            guard case .url(let url, let line) = declaration,
                let key = Institute.Repository.Key(url: url)
            else { return nil }
            return .init(
                repository: repository,
                line: line,
                url: url,
                institute: institute[key.name.underlying] ?? []
            )
        }
    }

    /// Reads the root manifest of every selected repository. Identity is the
    /// SwiftPM URL identity (the final repository-name component), so a URL
    /// from another owner that reuses an Institute package name is reported.
    func dependency(
        _ materialized: [(Institute.Repository, File.Directory)]
    ) -> Outcome {
        guard materialized.count == selection.repositories.count else {
            return Self.dependency.unmeasured(
                reason:
                    "\(materialized.count) of \(selection.repositories.count) selected "
                    + "repositories are materialized; package identity clashes cannot be "
                    + "proven from a partial fleet"
            )
        }

        var institute = [Swift.String: [Swift.String]]()
        for repository in configuration.repositories {
            institute[repository.name, default: []].append(repository.url)
        }
        for name in institute.keys {
            institute[name]?.sort()
        }
        var population = [Dependency]()
        for (repository, directory) in materialized {
            let file = directory[file: "Package.swift"]
            guard file.stat.isFile else {
                return Self.dependency.unmeasured(
                    reason: "\(repository.name) has no root Package.swift"
                )
            }

            let source: Swift.String
            do throws(Either<File.System.Read.Full.Error, Never>) {
                source = try file.read.full { bytes in
                    var storage = [Byte]()
                    storage.reserveCapacity(bytes.count)
                    for index in bytes.indices { storage.append(bytes[index]) }
                    return Swift.String(decoding: storage, as: Swift.UTF8.self)
                }
            } catch {
                return Self.dependency.unmeasured(
                    reason: "cannot read \(repository.name)/Package.swift: \(error)"
                )
            }

            do throws(Package.Dependency.Declaration.Parser.Error) {
                population += try Self.dependencies(
                    repository: repository.name,
                    source: source,
                    institute: institute
                )
            } catch {
                return Self.dependency.unmeasured(
                    reason: "cannot scan \(repository.name)/Package.swift: \(error)"
                )
            }
        }

        return Self.dependency.run(population: population, inventory: population.count)
    }
}
