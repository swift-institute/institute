public import File_System
public import Institute_Development
public import Institute_Inventory
public import Institute_Model
public import Institute_Pages

extension Institute.Doctor {
    /// One top-level Xcode workspace and the shared schemes it declares.
    public struct Workspace: Equatable, Sendable {
        public let repository: Swift.String
        public let name: Swift.String
        public let schemes: [Swift.String]

        public init(repository: Swift.String, name: Swift.String, schemes: [Swift.String]) {
            self.repository = repository
            self.name = name
            self.schemes = schemes
        }
    }
}

extension Institute.Doctor {
    /// Every top-level workspace has exactly one shared scheme, named after
    /// the workspace file including its `.xcworkspace` suffix.
    public static let workspace = Check<Workspace>(
        name: "workspace-scheme",
        scope: .contributor,
        controls: .init(
            positive: .init(
                repository: "control",
                name: "control.xcworkspace",
                schemes: ["other"]
            ),
            negative: .init(
                repository: "control",
                name: "control.xcworkspace",
                schemes: ["control.xcworkspace"]
            )
        )
    ) { workspace in
        workspace.schemes == [workspace.name]
            ? []
            : [
                .init(
                    severity: .error,
                    message:
                        "\(workspace.repository)/\(workspace.name): expected exactly one shared "
                        + "scheme named \(workspace.name); found "
                        + (workspace.schemes.isEmpty
                            ? "none"
                            : workspace.schemes.joined(separator: ", "))
                )
            ]
    }

    /// Reads each selected repository's top-level `.xcworkspace` bundles.
    /// A repository without a workspace contributes no subjects and is clean;
    /// a partial fleet or an unreadable directory cannot prove the rule.
    func workspace(
        _ materialized: [(Institute.Repository, File.Directory)]
    ) -> Outcome {
        guard materialized.count == selection.repositories.count else {
            return Self.workspace.unmeasured(
                reason:
                    "\(materialized.count) of \(selection.repositories.count) selected "
                    + "repositories are materialized; workspace schemes cannot be proven "
                    + "from a partial fleet"
            )
        }

        var population = [Workspace]()
        for (repository, directory) in materialized {
            let entries: [File.Directory.Entry]
            do throws(File.Directory.Contents.Error) {
                entries = try File.Directory.Contents.list(at: directory)
            } catch {
                return Self.workspace.unmeasured(
                    reason: "cannot enumerate \(repository.name): \(error)"
                )
            }

            for entry in entries where entry.type == .directory {
                guard
                    let name = Swift.String(entry.name),
                    name.hasSuffix(".xcworkspace"),
                    let path = entry.pathIfValid
                else { continue }

                let bundle = File.Directory(path)
                let shared = bundle[directory: "xcshareddata"][directory: "xcschemes"]
                let schemes: [Swift.String]
                if File(shared.path).stat.exists {
                    do throws(File.Directory.Contents.Error) {
                        schemes = try File.Directory.Contents.list(at: shared)
                            .compactMap { scheme in
                                guard scheme.type == .file,
                                    let filename = Swift.String(scheme.name),
                                    filename.hasSuffix(".xcscheme")
                                else { return nil }
                                return Swift.String(filename.dropLast(".xcscheme".count))
                            }
                            .sorted()
                    } catch {
                        return Self.workspace.unmeasured(
                            reason:
                                "cannot enumerate shared schemes in \(repository.name)/\(name): "
                                + "\(error)"
                        )
                    }
                } else {
                    schemes = []
                }
                population.append(
                    .init(repository: repository.name, name: name, schemes: schemes)
                )
            }
        }

        return Self.workspace.run(population: population, inventory: population.count)
    }
}
