public import File_System
private import Institute_Architecture_Candidates
private import Institute_Architecture_Facts
private import Institute_Architecture_Graph
private import Institute_Architecture_Index
public import Institute_Architecture_Model
private import Institute_Architecture_Validation
public import Institute_Model
private import Kernel

extension Institute.Architecture {
    /// The thin composition root behind `institute architecture validate`.
    ///
    /// It composes derivation, graph construction, index generation and
    /// validation; it owns no model logic of its own.
    public enum CLI {}
}

extension Institute.Architecture.CLI {
    /// Runs `institute architecture validate` from `path`.
    ///
    /// Ascends from `path` to the nearest directory holding
    /// `Institute.json`, derives the model, regenerates the index twice
    /// and requires identical digests, then validates Class I plus the
    /// derived contradiction checks. Returns the process exit status:
    /// `0` when validation passes, `1` when violations remain.
    public static func validate(
        path: Swift.String,
        report: (Swift.String) -> Swift.Void = { Swift.print($0) }
    ) throws(Error) -> Swift.Int32 {
        let root = try checkout(containing: path)
        let derived: Institute.Architecture.Facts
        do throws(Institute.Architecture.Facts.Error) {
            derived = try .derive(at: root)
        } catch {
            throw .derivation("\(error)")
        }
        let graph = derived.graph

        let first = Institute.Architecture.Index.generate(facts: derived.facts, graph: graph)
        let second = Institute.Architecture.Index.generate(facts: derived.facts, graph: graph)
        guard first.digest == second.digest else {
            throw .unstableIndex(first: "\(first.digest)", second: "\(second.digest)")
        }

        let outcome = Institute.Architecture.Validator().validate(
            derived: derived,
            today: today()
        )
        let candidates = Institute.Architecture.CandidateDetector().detect(in: derived.facts)

        report("architecture: \(derived.facts.count) package roots, \(derived.edges.count) edges")
        report("architecture: index digest \(first.digest) (regenerated twice, identical)")
        if let cycle = graph.cycle() {
            report(
                "architecture: dependency cycle \(cycle.map(\.description).joined(separator: " -> "))"
            )
        }
        for violation in outcome.violations {
            report("architecture: violation \(violation)")
        }
        for candidate in candidates {
            report(
                "architecture: advisory candidate '\(candidate.stem)' — "
                    + candidate.owners.map(\.description).joined(separator: ", ")
            )
        }
        report(
            outcome.passes
                ? "architecture: PASS"
                : "architecture: FAIL — \(outcome.violations.count) violations"
        )
        return outcome.passes ? 0 : 1
    }

    /// Ascends from `path` to the nearest directory containing
    /// `Institute.json`.
    internal static func checkout(containing path: Swift.String) throws(Error) -> File.Directory {
        var current = path
        while true {
            do throws(File.Path.Error) {
                let directory = try File.Directory(validating: current)
                do throws(Either<File.System.Read.Full.Error, Never>) {
                    _ = try directory[file: "Institute.json"].read.full { span in span.count }
                    return directory
                } catch {
                    // No readable inventory here; keep ascending.
                }
            } catch {
                // Not a directory; keep ascending.
            }
            guard let separator = current.lastIndex(of: "/"), separator != current.startIndex
            else {
                throw .noInstituteCheckout(searchedFrom: path)
            }
            current = Swift.String(current[..<separator])
        }
    }

    /// Today's UTC calendar day, without Foundation.
    internal static func today() -> Institute.Architecture.Exemption.Expiry {
        let seconds = Kernel.Time.realtime().secondsSinceUnixEpoch
        var days = Swift.Int(seconds) / 86_400
        // Civil-from-days (Howard Hinnant's algorithm), epoch 1970-01-01.
        days += 719_468
        let era = (days >= 0 ? days : days - 146_096) / 146_097
        let dayOfEra = days - era * 146_097
        let yearOfEra =
            (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146_096) / 365
        let year = yearOfEra + era * 400
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthIndex = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * monthIndex + 2) / 5 + 1
        let month = monthIndex < 10 ? monthIndex + 3 : monthIndex - 9
        let civilYear = month <= 2 ? year + 1 : year
        let text =
            zeroPadded(civilYear, to: 4) + "-" + zeroPadded(month, to: 2) + "-"
            + zeroPadded(day, to: 2)
        // The canonical form above is valid by construction.
        do throws(Institute.Architecture.Exemption.Error) {
            return try Institute.Architecture.Exemption.Expiry(rawValue: text)
        } catch {
            Swift.preconditionFailure(
                "civil-from-days produced a non-canonical expiry '\(text)': \(error)"
            )
        }
    }

    private static func zeroPadded(_ value: Swift.Int, to width: Swift.Int) -> Swift.String {
        var text = Swift.String(value)
        while text.count < width { text = "0" + text }
        return text
    }
}
