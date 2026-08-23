import Foundation
import Package_Manager

extension Institute.Application.CI {
    static func package(_ arguments: [String]) {
        guard let operation = arguments.first else {
            refuse("package requires validate, plan, or aggregate")
        }
        let rest = Array(arguments.dropFirst())
        switch operation {
        case "validate": packageValidate(rest)

        case "plan": plan(rest)

        case "aggregate": aggregate(rest)

        default: refuse("package requires validate, plan, or aggregate")
        }
    }

    private static func packageValidate(_ arguments: [String]) {
        let repository = value("--repository", in: arguments)
        let root = value("--root", in: arguments)
        let policy = value("--policy", in: arguments)
        guard !repository.isEmpty, !root.isEmpty, !policy.isEmpty else {
            refuse("package validate requires --repository, --root, and --policy")
        }

        let fleet: RepositoryPolicy.Fleet
        do {
            fleet = try RepositoryPolicy.Fleet.read(at: policy)
        } catch {
            refuse("package validate could not read fleet policy: \(error)")
        }
        guard fleet.schemaVersion == 1 else {
            refuse("package validate requires fleet policy schemaVersion 1")
        }

        let dependencies = dependencyFacts(root: root)
        var refused = false
        for finding in RepositoryPolicy.BranchPin.findings(
            in: dependencies,
            organizations: fleet.activeOrganizationNames
        ) {
            refused = true
            print(
                "\(repository)\tBRANCH-PIN-001\t\(finding.document): `\(finding.url)` "
                    + "pinned to branch \"\(finding.branch)\"; Institute dependencies use main"
            )
        }

        if repository.split(separator: "/").last != "swift-html-prism" {
            for finding in identityFindings(root: root) {
                switch finding.disposition {
                case .fatal:
                    refused = true
                    print("\(repository)\tIDENTITY-CONFLICT\t\(identityMessage(finding))")

                case .stalePin:
                    print("\(repository)\tIDENTITY-CONFLICT-STALE-PIN\t\(identityMessage(finding))")
                }
            }
        }

        let evaluation: Package.Manifest.Evaluation
        do {
            evaluation = try Package.Manager().evaluation(at: root)
        } catch {
            refuse("package validate could not evaluate manifest: \(error)")
        }
        for finding in RepositoryPolicy.TestSupport.findings(in: evaluation) {
            print(
                "\(repository)\tTEST-SUPPORT-INTEGRITY\t\(finding.target) depends on "
                    + "non-support product or target \(finding.dependency)"
            )
        }

        do {
            for finding in try RepositoryPolicy.BrokenSymlink.findings(at: root) {
                print("\(repository)\tBROKEN-SYMLINK\t\(finding.path)")
            }
        } catch {
            refuse("package validate could not evaluate symbolic links: \(error)")
        }

        if refused { terminate(1) }
    }

    private static func dependencyFacts(
        root: String
    ) -> [Package.Manifest.Dependency.SourceControl] {
        rootManifestNames(root: root).flatMap {
            name -> [Package.Manifest.Dependency.SourceControl] in
            guard let data = FileManager.default.contents(atPath: root + "/" + name) else {
                return []
            }
            return Package.Manifest.Dependency.SourceControl.all(
                in: String(decoding: data, as: UTF8.self),
                document: name
            )
        }
    }

    private static func identityFindings(
        root: String
    ) -> [Package.Manifest.Identity.Conflict.Finding] {
        var entries: [Package.Manifest.Identity.Conflict.Entry] = []
        for name in rootManifestNames(root: root) {
            guard let data = FileManager.default.contents(atPath: root + "/" + name) else {
                continue
            }
            entries += Package.Manifest.Identity.Conflict.entries(
                in: String(decoding: data, as: UTF8.self),
                document: name
            )
        }

        if let data = FileManager.default.contents(atPath: root + "/Package.resolved") {
            entries += Package.Manifest.Identity.Conflict.entries(
                inResolved: String(decoding: data, as: UTF8.self)
            )
        }
        return Package.Manifest.Identity.Conflict.findings(in: entries)
    }

    private static func rootManifestNames(root: String) -> [String] {
        let names: [String]
        do {
            names = try FileManager.default.contentsOfDirectory(atPath: root)
        } catch {
            refuse("package validate could not read root: \(error)")
        }
        return names.filter(Package.Manifest.Identity.Conflict.isRootManifest).sorted()
    }

    private static func identityMessage(
        _ finding: Package.Manifest.Identity.Conflict.Finding
    ) -> String {
        let locations = Dictionary(grouping: finding.entries, by: \.location)
            .keys.sorted()
            .map { location in
                let documents = finding.entries
                    .filter { $0.location == location }
                    .map(\.document).sorted().joined(separator: ", ")
                return "\(location) [\(documents)]"
            }
            .joined(separator: "; ")
        return "identity '\(finding.identity)' has distinct canonical locations: \(locations)"
    }
}
