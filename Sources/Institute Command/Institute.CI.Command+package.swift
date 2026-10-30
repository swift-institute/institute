import Institute_CI_Model
import Institute_Model
import Institute_Repository_Policy
import Package_Manager

import struct Swift.String

extension Institute.CI.Command {
    static func package(_ arguments: [Swift.String]) {
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

    private static func packageValidate(_ arguments: [Swift.String]) {
        let repository = value("--repository", in: arguments)
        let root = value("--root", in: arguments)
        let policy = value("--policy", in: arguments)
        guard !repository.isEmpty, !root.isEmpty, !policy.isEmpty else {
            refuse("package validate requires --repository, --root, and --policy")
        }

        let fleet: Institute.Repository.Policy.Fleet
        do throws(Institute.Repository.Policy.Fleet.Error) {
            fleet = try Institute.Repository.Policy.Fleet.read(at: policy)
        } catch {
            refuse("package validate could not read fleet policy: \(error)")
        }
        guard fleet.schemaVersion == 1 else {
            refuse("package validate requires fleet policy schemaVersion 1")
        }

        let manifest: Institute.Repository.Policy.Manifest
        do throws(Institute.Repository.Policy.Manifest.Error) {
            manifest = try Institute.Repository.Policy.Manifest.read(at: root)
        } catch {
            refuse("package validate could not read root")
        }
        var refused = false
        for finding in Institute.Repository.Policy.BranchPin.findings(
            in: manifest.dependencies,
            organizations: fleet.activeOrganizationNames
        ) {
            refused = true
            print(
                "\(repository)\tBRANCH-PIN-001\t\(finding.document): `\(finding.url)` "
                    + "pinned to branch \"\(finding.branch)\"; Institute dependencies use main"
            )
        }

        for finding in manifest.identityFindings(repository: repository) {
            switch finding.disposition {
            case .fatal:
                refused = true
                print("\(repository)\tIDENTITY-CONFLICT\t\(identityMessage(finding))")

            case .stalePin:
                print("\(repository)\tIDENTITY-CONFLICT-STALE-PIN\t\(identityMessage(finding))")
            }
        }

        let evaluation: Package.Manifest.Evaluation
        do {
            evaluation = try Package.Manager().evaluation(at: root)
        } catch {
            refuse("package validate could not evaluate manifest: \(error)")
        }
        for finding in Institute.Repository.Policy.TestSupport.findings(in: evaluation) {
            print(
                "\(repository)\tTEST-SUPPORT-INTEGRITY\t\(finding.target) depends on "
                    + "non-support product or target \(finding.dependency)"
            )
        }

        do throws(Institute.Repository.Policy.BrokenSymlink.Error) {
            for finding in try Institute.Repository.Policy.BrokenSymlink.findings(at: root) {
                print("\(repository)\tBROKEN-SYMLINK\t\(finding.path)")
            }
        } catch {
            refuse("package validate could not evaluate symbolic links: \(error)")
        }

        if refused { terminate(1) }
    }

    private static func identityMessage(
        _ finding: Package.Manifest.Identity.Conflict.Finding
    ) -> Swift.String {
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
