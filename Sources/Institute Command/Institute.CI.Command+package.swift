import File_System
import Institute_CI_Model
import Institute_CI_Validation
import Institute_Model
import Institute_Repository_Policy
import Package_Manager

import struct Swift.String

extension Institute.CI.Command {
    static func package(_ arguments: [Swift.String]) {
        guard let operation = arguments.first else {
            refuse("package requires validate, readme, plan, or aggregate")
        }
        let rest = Array(arguments.dropFirst())
        switch operation {
        case "validate": packageValidate(rest)

        case "readme": packageReadme(rest)

        case "plan": plan(rest)

        case "aggregate": aggregate(rest)

        default: refuse("package requires validate, readme, plan, or aggregate")
        }
    }

    private static func packageValidate(_ arguments: [Swift.String]) {
        let repository = value("--repository", in: arguments)
        let root = value("--root", in: arguments)
        guard !repository.isEmpty, !root.isEmpty else {
            refuse("package validate requires --repository and --root")
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
            organizations: Swift.Set(Institute.Organization.allCases.map(\.rawValue))
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
            evaluation = try Package.Manager().evaluation(at: File.Directory(validating: root))
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

        do throws(Institute.CI.Validation.EnvironmentDefect) {
            let tracked = try Institute.CI.Validation.Gitignore.indexedPaths(in: root)
            for path in Institute.Repository.Policy.ToolState.findings(in: tracked) {
                refused = true
                print("\(repository)\tTOOL-STATE-001\t\(Institute.Repository.Policy.ToolState.message(path))")
            }
            for path in Institute.Repository.Policy.Prose.findings(in: tracked, repository: repository) {
                print("\(repository)\tPROSE-001\t\(Institute.Repository.Policy.Prose.message(path))")
            }
        } catch {
            refuse("package validate could not read the tracked paths: \(error)")
        }

        if readmeFindings(repository: repository, root: root) { refused = true }

        if refused { terminate(1) }
    }

    /// `package readme`: the README rules alone, for a repository with no
    /// package to validate, such as an organization's `.github`.
    private static func packageReadme(_ arguments: [Swift.String]) {
        let repository = value("--repository", in: arguments)
        let root = value("--root", in: arguments)
        guard !repository.isEmpty, !root.isEmpty else {
            refuse("package readme requires --repository and --root")
        }
        if readmeFindings(repository: repository, root: root) { terminate(1) }
    }

    /// Prints each README finding, and says whether there were any.
    private static func readmeFindings(repository: Swift.String, root: Swift.String) -> Swift.Bool {
        do throws(Institute.CI.Validation.EnvironmentDefect) {
            let subject = Institute.CI.Validation.Subject(repository: repository, root: root)
            let findings = try Institute.CI.Validation.Readme().findings(in: subject)
            for finding in findings { print(finding.tsv) }
            return !findings.isEmpty
        } catch {
            refuse("could not read the README: \(error)")
        }
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
