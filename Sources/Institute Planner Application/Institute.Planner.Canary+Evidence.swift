import File_System
public import Institute_Model
import Institute_Repository_Policy

extension Institute.Planner.Canary {
    /// Runs the canary of publish run `run` over `repositories` in the fresh
    /// directory `work`, and returns its evidence.
    ///
    /// Both planners are verified before anything runs: the candidate
    /// against its own PIN and SHA256SUMS assets, the current planner —
    /// the consumer's winning macOS row for its pinned revision — against
    /// the publication that carries that row. Each repository is cloned
    /// once at its default-branch head; the current planner measures it,
    /// then a second clone of that exact revision takes the same path for
    /// the candidate, so the two reports name the same root.
    ///
    /// A contract or verification failure refuses the whole canary; a
    /// repository that cannot be cloned or measured is recorded as not
    /// having run, which no candidate can be adopted over.
    public static func evidence(
        run: Swift.String,
        repositories: [Swift.String],
        work: Swift.String,
        xcode: Swift.String,
        release: Institute.Planner.Release,
        consumer: Institute.Planner.Consumer,
        runner: Runner
    ) -> Institute.Planner.Evidence {
        do throws(Institute.Planner.Error) {
            let publication = try release.publication(run: run)
            let candidate = try release.executable(.macos, of: publication)
            let current = try release.executable(
                .macos,
                of: release.publication(carrying: consumer.current(.macos))
            )
            let planner = "\(work)/planner"
            try Institute.Planner.directory(Institute.Planner.path(planner))
            let binaries = (
                current: try install(current, at: "\(planner)/institute-current"),
                candidate: try install(candidate, at: "\(planner)/institute-candidate")
            )
            let fleet = try fleet(consumer, at: "\(planner)/fleet.json")

            var comparisons: [Comparison] = []
            for name in repositories {
                let bundle: Swift.String
                do throws(Institute.Repository.Policy.Fleet.Error) {
                    bundle = try fleet.configuration(for: name).lintBundle
                } catch {
                    throw .missing("fleet lint bundle for \(name): \(error)")
                }
                comparisons.append(
                    compare(
                        repository: name,
                        url: "https://github.com/\(name).git",
                        bundle: bundle,
                        base: "\(work)/\(name)",
                        xcode: xcode,
                        binaries: binaries,
                        runner: runner
                    )
                )
            }
            return .init(
                run: run,
                candidate: candidate,
                current: current,
                rows: publication.rows,
                xcode: xcode,
                repositories: comparisons
            )
        } catch {
            return .init(run: run, refusal: error)
        }
    }

    /// Clones, measures with both binaries, and compares one repository.
    static func compare(
        repository: Swift.String,
        url: Swift.String,
        bundle: Swift.String,
        base: Swift.String,
        xcode: Swift.String,
        binaries: (current: Swift.String, candidate: Swift.String),
        runner: Runner
    ) -> Comparison {
        let subject = "\(base)/subject"
        var revision = ""
        func measure(_ binary: Swift.String) throws(Institute.Planner.Error) -> Outcome {
            let pinned = try Institute.Planner.Revision(revision)
            return Outcome(
                try runner.execute(
                    binary,
                    arguments(
                        repository: repository,
                        revision: pinned,
                        root: subject,
                        bundle: bundle,
                        xcode: xcode
                    )
                )
            )
        }
        do throws(Institute.Planner.Error) {
            try Institute.Planner.directory(Institute.Planner.path(base))
            revision = try runner.clone(url, subject).description
            let current = try measure(binaries.current)
            try move(subject, to: "\(base)/current")
            let again = try runner.clone("file://\(base)/current", subject)
            guard again.description == revision else {
                throw .local("\(repository): the second clone is at \(again), not \(revision)")
            }
            let candidate = try measure(binaries.candidate)
            try move(subject, to: "\(base)/candidate")
            return .init(
                repository: repository,
                revision: revision,
                bundle: bundle,
                current: current,
                candidate: candidate
            )
        } catch {
            let failed = Outcome(status: .crashed, code: nil, unmeasured: ["\(error)"])
            return .init(
                repository: repository,
                revision: revision,
                bundle: bundle,
                current: failed,
                candidate: failed
            )
        }
    }

    /// Writes a verified binary to `path` as an executable file.
    private static func install(
        _ executable: Institute.Planner.Executable,
        at path: Swift.String
    ) throws(Institute.Planner.Error) -> Swift.String {
        let file = try Institute.Planner.path(path)
        try Institute.Planner.write(executable.binary, to: file)
        do throws(File.System.Metadata.Permissions.Error) {
            try File.System.Metadata.Permissions.set(.executable, at: file)
        } catch {
            throw .local("cannot make \(path) executable: \(error)")
        }
        return path
    }

    /// The fleet policy on the consumer's default branch, read through the
    /// policy's own reader from a copy at `path`.
    private static func fleet(
        _ consumer: Institute.Planner.Consumer,
        at path: Swift.String
    ) throws(Institute.Planner.Error) -> Institute.Repository.Policy.Fleet {
        try Institute.Planner.write(
            consumer.read(Institute.Planner.Consumer.fleet),
            to: Institute.Planner.path(path)
        )
        do throws(Institute.Repository.Policy.Fleet.Error) {
            return try Institute.Repository.Policy.Fleet.read(at: path)
        } catch {
            throw .malformed(line: Institute.Planner.Consumer.fleet, reason: "\(error)")
        }
    }

    private static func move(
        _ source: Swift.String,
        to destination: Swift.String
    ) throws(Institute.Planner.Error) {
        let from = try Institute.Planner.path(source)
        let to = try Institute.Planner.path(destination)
        do throws(File.System.Move.Error) {
            try File.System.Move.move(from: from, to: to)
        } catch {
            throw .local("cannot move \(source) to \(destination): \(error)")
        }
    }
}
