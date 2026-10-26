import Byte
import Calendar_Gregorian
import GitHub_App
public import Institute_Model
public import Institute_Repository_Policy
import JSON
import RFC_3339
import Time

import struct Swift.String

extension Institute.Repository.Policy.Command {
    /// `institute repository census --repo <name>=<root>=<headSha> ... --output <csv>`
    ///
    /// Regenerates the FT1 census from checked-out trees at the given heads
    /// (F1; swift-institute/.github#363). Deterministic sorted traversal;
    /// parity with the FT1 artifact is order-normalized.
    static func census(_ arguments: [Swift.String]) throws(Error) {
        var repos: [Census.Generator.Repo] = []
        var output: Swift.String?
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--repo":
                guard let value = iterator.next() else {
                    throw configuration("--repo needs <name>=<root>=<headSha>")
                }
                let parts = value.split(separator: "=", maxSplits: 2).map(Swift.String.init)
                guard parts.count == 3 else {
                    throw configuration("--repo needs <name>=<root>=<headSha>")
                }
                repos.append(.init(name: parts[0], root: parts[1], headSha: parts[2]))

            case "--output":
                output = iterator.next()

            default:
                throw configuration("unknown census argument \(argument)")
            }
        }
        guard let output, !repos.isEmpty else {
            throw configuration("census requires --repo … and --output")
        }
        let census: Institute.Repository.Policy.Census
        do throws(Census.Generator.Error) {
            census = try Census.Generator(repos: repos).run()
        } catch {
            throw .census(error)
        }
        try write([Byte](utf8: census.normalized.csv), to: output)
        var byKind: [Swift.String: Int] = [:]
        for row in census.rows {
            byKind[row.coordinateKind.rawValue, default: 0] += 1
        }
        let summary = byKind.sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("institute repository: census rows=\(census.rows.count) \(summary)")
    }

    /// `institute repository capability-records --output <json>` — emits
    /// the FT1-frozen D-01…D-12 capability records.
    static func capabilityRecords(_ arguments: [Swift.String]) throws(Error) {
        guard arguments.count == 2, arguments[0] == "--output" else {
            throw configuration("capability-records requires --output <path>")
        }
        let records = Institute.Repository.Policy.Capability.records
        var bytes = [Byte](utf8: records.jsonString(pretty: true, sortKeys: true))
        bytes.append(Byte(0x0A))
        try write(bytes, to: arguments[1])
        print(
            "institute repository: capability-records count=\(records.count)"
        )
    }

    /// `institute repository render-caller [--form terminal]`
    ///
    /// Prints the terminal caller, the bytes every package carries (F3;
    /// #366). The `current` and `direct` migration forms, and
    /// `parse-caller` that read them back, were retired once the caller wave
    /// had converged the fleet onto the terminal form.
    static func renderCaller(_ arguments: [Swift.String]) throws(Error) {
        guard arguments.isEmpty || arguments == ["--form", "terminal"] else {
            throw configuration("render-caller takes no arguments but --form terminal")
        }
        print(Institute.Repository.Policy.Caller.Render.terminal, terminator: "")
    }

    /// `institute repository draft-metadata --repository <owner/name>
    /// [--spec-titles <path>] [--package-description <text>]
    /// [--date <YYYY-MM-DD>]`
    ///
    /// Prints the bootstrap `.github/metadata.yaml` draft to stdout — the
    /// decision half of the retired `generate-metadata.sh`. The clone,
    /// commit, and pull request stay in workflow plumbing over a token,
    /// and keeping them out is what lets the classification be tested
    /// without one.
    static func draftMetadata(_ arguments: [Swift.String]) throws(Error) {
        var repository: Swift.String?
        var specTitles: Swift.String?
        var packageDescription = ""
        var date: Swift.String?
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--repository": repository = iterator.next()
            case "--spec-titles": specTitles = iterator.next()
            case "--package-description": packageDescription = iterator.next() ?? ""
            case "--date": date = iterator.next()

            default:
                throw configuration("unknown draft-metadata argument \(argument)")
            }
        }
        guard let repository else {
            throw configuration("draft-metadata requires --repository")
        }
        var titles = Institute.Repository.Policy.Metadata.Draft.Titles()
        if let specTitles {
            titles = .init(parsing: try text(at: specTitles, label: "spec titles"))
        }
        let draft: Institute.Repository.Policy.Metadata.Draft
        do throws(Institute.Repository.Policy.Metadata.Error) {
            draft = try Institute.Repository.Policy.Metadata.Draft(
                target: repository,
                titles: titles,
                packageDescription: packageDescription
            )
        } catch {
            throw .metadata(error)
        }
        let render = Institute.Repository.Policy.Metadata.Draft.Render(
            generatedOn: date ?? Self.today
        )
        print(render(draft), terminator: "")
    }

    /// Today in UTC, `YYYY-MM-DD` — the header stamp the retired script
    /// took from `date -u +%Y-%m-%d`. Overridable by `--date` so a test
    /// (and a re-run of the same draft) renders the same bytes.
    private static var today: Swift.String {
        let now = Gregorian.DateTime(Time.Instant(secondsSinceUnixEpoch: GitHub.App.Clock.now()))
        return Swift.String(now.rfc3339.format(offset: .utc, precision: 0).prefix(10))
    }
}
