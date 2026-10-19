import Byte
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

    /// `institute repository parse-caller --caller <ci.yml> --repository
    /// <owner/name>`
    ///
    /// The inverse of `render-caller`, and the Swift owner of the retired
    /// `generate-caller.py parse` mode (F16 C3).
    ///
    /// Prints the recovered spec as JSON in the shape the retired mode
    /// emitted — `layer`, `same_org`, and one snake-cased field per
    /// approved typed input, `null` where the caller supplies none — so a
    /// consumer reading the old payload reads this one. A caller carrying
    /// something the renderer does not model exits non-zero naming it,
    /// rather than reporting a spec that would silently erase it.
    static func parseCaller(_ arguments: [Swift.String]) throws(Error) {
        var caller: Swift.String?
        var repository: Swift.String?
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--caller": caller = iterator.next()
            case "--repository": repository = iterator.next()

            default:
                throw configuration("unknown parse-caller argument \(argument)")
            }
        }
        guard let caller, let repository else {
            throw configuration(
                "parse-caller requires --caller <ci.yml> and --repository <owner/name>"
            )
        }
        let text = try text(at: caller, label: "caller")
        let spec: Institute.Repository.Policy.Caller
        do throws(Institute.Repository.Policy.Caller.Error) {
            spec = try Institute.Repository.Policy.Caller.Parse.caller(
                text,
                repository: repository
            )
        } catch {
            throw .caller(error)
        }

        var payload: [Swift.String: JSON] = [
            "layer": spec.layer.rawValue.json,
            "same_org": (spec.sameOrganization ? "true" : "false").json,
        ]
        for key in Institute.Repository.Policy.Caller.approvedTypedInputs {
            let value = spec.inputs.first { $0.key == key }?.value
            payload[key.replacing("-", with: "_")] = value.json
        }
        print(
            JSON.object(payload.map { ($0.key, $0.value) })
                .serialize(pretty: true, sortKeys: true)
        )
    }

    /// `institute repository render-caller [--form terminal]`
    ///
    /// The superseded `current` and `direct` forms still accept their former
    /// repository, layer, input, and private-closure arguments until their
    /// final migration consumer is deleted.
    ///
    /// Prints the deterministic host projection to stdout (F3; #366).
    static func renderCaller(_ arguments: [Swift.String]) throws(Error) {
        var repository: Swift.String?
        var layer: Institute.Repository.Policy.Caller.Layer?
        var inputs: [(key: Swift.String, value: Swift.String)] = []
        var form = "terminal"
        var privateClosure = false
        var iterator = arguments.makeIterator()
        while let argument = iterator.next() {
            switch argument {
            case "--repository": repository = iterator.next()

            case "--layer":
                guard let raw = iterator.next(),
                    let value = Institute.Repository.Policy.Caller.Layer(rawValue: raw)
                else {
                    throw configuration("--layer must be primitives|standards|institute")
                }
                layer = value

            case "--input":
                guard let raw = iterator.next(),
                    let separator = raw.firstIndex(of: "=")
                else {
                    throw configuration("--input needs <key>=<value>")
                }
                let key = Swift.String(raw[..<separator])
                guard Institute.Repository.Policy.Caller.approvedTypedInputs.contains(key)
                else {
                    throw configuration("unapproved input key \(key)")
                }
                inputs.append(
                    (key: key, value: Swift.String(raw[raw.index(after: separator)...]))
                )

            case "--form":
                guard let value = iterator.next() else {
                    throw configuration("--form requires a value")
                }
                form = value

            case "--private-dependency-closure": privateClosure = true

            default:
                throw configuration("unknown render-caller argument \(argument)")
            }
        }
        if form == "terminal" {
            print(Institute.Repository.Policy.Caller.Render.terminal, terminator: "")
            return
        }
        guard let repository, let layer else {
            throw configuration(
                "render-caller --form \(form) requires --repository and --layer"
            )
        }
        let caller: Institute.Repository.Policy.Caller
        do throws(Institute.Repository.Policy.Caller.Error) {
            caller = try Institute.Repository.Policy.Caller(
                repository: repository,
                layer: layer,
                inputs: inputs
            )
        } catch {
            throw .caller(error)
        }
        switch form {
        case "current":
            print(Institute.Repository.Policy.Caller.Render.current(caller), terminator: "")

        case "direct":
            print(
                Institute.Repository.Policy.Caller.Render.direct(
                    caller,
                    privateDependencyClosure: privateClosure
                ),
                terminator: ""
            )

        default:
            throw configuration("--form must be current|direct|terminal")
        }
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
    /// (and a re-run of the same wave) renders the same bytes.
    private static var today: Swift.String {
        Swift.String(issuedAt.prefix(10))
    }
}
