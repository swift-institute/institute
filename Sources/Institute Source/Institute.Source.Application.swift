import Byte
import FIPS_180_4
public import File_System
public import Institute_Model
public import Institute_Source_Policy
internal import Institute_Source_Profile
import Source_Execution
public import Source_Measurement
internal import Source_Profile
import Source_Repair
import Source_Swift_Format
import Thread_Pool

extension Institute.Source.Application {
    /// Applies what `Source.Repair` can to `subject`: the rewrite `swift-format`
    /// proposes, under the policy's repair configuration, for each file it has
    /// a finding in under that configuration (spacing, indentation, import
    /// order and the other correctable rules).
    ///
    /// A file is rewritten only when its proposed text has no finding left
    /// under the repair configuration; any other file is left as it was and
    /// named in the result. The rewrites are staged, measured again as one
    /// tree, and applied as one `Source.Repair.Transaction`, which changes
    /// every file or none.
    public func repair(
        subject: Source_Measurement::Source.Subject,
        bundle: Institute.Source.Bundle,
        preparation: Institute.Source.Preparation
    ) async throws(Institute.Error) -> Institute.Source.Repaired {
        guard preparation.binding == .package(subject.binding) else {
            throw .configuration("source preparation is for another subject than \(subject.identity)")
        }
        if let reason = Self.staleness(of: preparation) {
            throw .configuration("source preparation is stale: \(reason.code): \(reason.detail)")
        }
        let policy = Institute.Source.Policy.current
        let format = Source_Measurement::Source.Engine.ID("swift-format")
        let profile = policy.profile(
            swiftFormat: (
                executable: preparation.swiftFormatExecutable, tool: preparation.swiftFormatTool,
                configurationPath: "\(preparation.directory)/\(policy.swiftFormatRepair.path)"
            ),
            swiftLint: (
                executable: preparation.swiftLintExecutable, tool: preparation.swiftLintTool,
                configurationPath: "\(preparation.directory)/\(policy.swiftLint.path)"
            ),
            linter: (
                executable: preparation.linterExecutable, tool: preparation.linterTool,
                configurationPath: "\(preparation.directory)/\(bundle.token)-source-linter-profile.json"
            ),
            bundle: bundle,
            linterRules: Institute.Source.Profile(policy: policy).rules(for: bundle),
            repository: subject.repository.flatMap { Institute.Repository.Coordinate($0) },
            repair: true,
            linterEnvironment: Self.runtime(swiftFormat: preparation.swiftFormatExecutable)
        )
        guard let engine = profile.engines.first(where: { $0.id == format }) else {
            throw .configuration("the repair profile has no swift-format engine")
        }
        let driver = Source_Measurement::Source.Engine.Driver.swiftFormat(process: process)
        let execution: Source_Execution::Source.Execution
        do throws(Source_Execution::Source.Execution.Error) {
            execution = try .init(drivers: [driver])
        } catch {
            throw .configuration("cannot register the swift-format engine: \(error)")
        }

        let measured = try Self.only(await execution.measure(subject, profile: profile, engines: [format]))
        let findings: [Source_Measurement::Source.Finding]
        switch measured.verdict {
        case .clean, .notRequested: return .init(rewritten: [], declined: [])
        case .unmeasured(let reasons): throw .process("swift-format did not measure: \(Self.text(reasons))")
        case .findings(let found): findings = found
        }

        let prefix = subject.root.hasSuffix("/") ? subject.root : subject.root + "/"
        let proposal = await driver.repair(subject.governed, engine)
        var proposed: [Swift.String: [Swift.UInt8]] = [:]
        for edit in proposal.edits where edit.path.hasPrefix(prefix) {
            proposed[Swift.String(edit.path.dropFirst(prefix.count))] = edit.replacement
        }
        var declined: [Swift.String: Swift.String] = [:]
        for refusal in proposal.refusals {
            let file = refusal.detail.hasPrefix(prefix) ? Swift.String(refusal.detail.dropFirst(prefix.count)) : refusal.detail
            declined[file] = "swift-format could not rewrite it: \(refusal.code)"
        }

        let files = Self.files(root: subject.root)
        var originals: [Swift.String: [Swift.UInt8]] = [:]
        for path in subject.paths(of: .swift) {
            switch files.read(path) {
            case .success(let contents): originals[path] = contents
            case .failure(let reason): throw .filesystem("cannot read \(path): \(reason.detail)")
            }
        }
        for (path, replacement) in proposed where originals[path] == replacement {
            proposed[path] = nil
        }
        guard !proposed.isEmpty else {
            return .init(rewritten: [], declined: declined.map { .init(file: $0.key, reason: $0.value) })
        }

        let scratch = preparation.directory[directory: "repair"]
        defer {
            do throws(File.System.Delete.Error) {
                if scratch.stat.exists { try scratch.delete.recursive() }
            } catch {}
        }
        var staged = originals.merging(proposed, uniquingKeysWith: { _, replacement in replacement })
        var remeasured = try await Self.measure(
            staged,
            in: scratch,
            as: subject,
            profile: profile,
            execution: execution
        )
        let leftover = Self.unrepaired(in: remeasured, prefix: prefix).intersection(proposed.keys)
        if !leftover.isEmpty {
            for path in leftover {
                proposed[path] = nil
                staged[path] = originals[path]
                declined[path] = "its rewrite still has findings under the repair configuration"
            }
            guard !proposed.isEmpty else {
                return .init(rewritten: [], declined: declined.map { .init(file: $0.key, reason: $0.value) })
            }
            remeasured = try await Self.measure(
                staged,
                in: scratch,
                as: subject,
                profile: profile,
                execution: execution
            )
        }

        let rule = Source_Measurement::Source.Rule.ID(engine: format, token: "format")
        let planned = Source_Measurement::Source.Measurement(
            engine: measured.engine,
            subject: measured.subject,
            activeRules: measured.activeRules,
            applicableRules: measured.applicableRules,
            files: measured.files,
            observations: measured.observations,
            suppressions: measured.suppressions,
            repairs: proposed.keys.map { path in
                .init(
                    file: prefix + path,
                    rule: rule,
                    disposition: .edits([
                        .rewrite(
                            path: prefix + path,
                            contents: Swift.String(decoding: proposed[path] ?? [], as: Swift.UTF8.self)
                        )
                    ])
                )
            },
            controls: measured.controls,
            verdict: .findings(
                findings.map { finding in
                    guard let file = finding.diagnostic.location.filePath, file.hasPrefix(prefix),
                        proposed[Swift.String(file.dropFirst(prefix.count))] != nil
                    else { return finding }
                    return .init(rule: finding.rule, diagnostic: finding.diagnostic, repair: .automatic)
                }
            )
        )
        let sources = Source_Repair::Source.SourceSet.digest(
            originals.map { path, contents in .init(path: path, contents: contents) }
        )
        let plan: Source_Repair::Source.Repair.Plan
        do throws(Source_Measurement::Source.Reason) {
            plan = try Source_Repair::Source.Repair.Staging(
                subject: subject,
                profile: profile.digest,
                sources: sources,
                measurements: [planned],
                selection: .init(automaticRules: nil),
                fileSystem: files
            ).finish(remeasured: [remeasured])
        } catch {
            throw .process("source repair could not be staged: \(error.code): \(error.detail)")
        }
        guard plan.refusals.isEmpty else {
            throw .process("source repair refused: \(Self.text(plan.refusals.map(\.reason)))")
        }
        let applied = Source_Repair::Source.Repair.Transaction().apply([
            .init(plan: plan, subject: subject.binding, profile: profile.digest, sources: sources, files: files)
        ])
        if case .failure(let reason) = applied {
            throw .filesystem("source repair was not applied: \(reason.code): \(reason.detail)")
        }
        return .init(
            rewritten: Swift.Array(proposed.keys),
            declined: declined.map { .init(file: $0.key, reason: $0.value) }
        )
    }
}

extension Institute.Source.Application {
    /// Measures `contents`, written out under `scratch`, and reports the
    /// result as a measurement of `subject`: the same tree with other text,
    /// every path named where it is in the subject.
    private static func measure(
        _ contents: [Swift.String: [Swift.UInt8]],
        in scratch: File.Directory,
        as subject: Source_Measurement::Source.Subject,
        profile: Source_Profile::Source.Profile,
        execution: Source_Execution::Source.Execution
    ) async throws(Institute.Error) -> Source_Measurement::Source.Measurement {
        do throws(Either<Kernel.Thread.Pool.Error, File.System.Delete.Error>) {
            if scratch.stat.exists { try await scratch.delete.recursive() }
        } catch { throw .filesystem("cannot clear \(scratch): \(error)") }
        let files = files(root: scratch.description)
        for (path, bytes) in contents {
            if case .failure(let reason) = files.write(path, bytes) {
                throw .filesystem("cannot stage \(path): \(reason.detail)")
            }
        }
        let copy = Source_Measurement::Source.Subject(
            identity: subject.identity,
            root: scratch.description,
            artifacts: subject.artifacts.map { artifact in
                .init(
                    path: artifact.path,
                    kind: artifact.kind,
                    purpose: artifact.purpose,
                    provenance: artifact.provenance,
                    digest: .init(
                        FIPS_180_4.SHA256.digest((contents[artifact.path] ?? []).map(Byte.init(_:))).hex
                    )
                )
            }
        )
        let measured = try only(
            await execution.measure(copy, profile: profile, engines: Swift.Set(profile.engines.map(\.id)))
                .filter { $0.engine.token == "swift-format" }
        )
        if case .unmeasured(let reasons) = measured.verdict {
            throw .process("swift-format did not measure the staged repair: \(text(reasons))")
        }
        return relocated(measured, from: scratch.description, to: subject)
    }

    /// `measurement`, made of a copy of `subject` under `scratch`, with every
    /// path named under the subject's own root.
    static func relocated(
        _ measurement: Source_Measurement::Source.Measurement,
        from scratch: Swift.String,
        to subject: Source_Measurement::Source.Subject
    ) -> Source_Measurement::Source.Measurement {
        let from = scratch.hasSuffix("/") ? scratch : scratch + "/"
        let to = subject.root.hasSuffix("/") ? subject.root : subject.root + "/"
        func moved(_ path: Swift.String) -> Swift.String {
            path.hasPrefix(from) ? to + path.dropFirst(from.count) : path
        }
        func moved(_ finding: Source_Measurement::Source.Finding) -> Source_Measurement::Source.Finding {
            let location = finding.diagnostic.location
            let repair: Source_Measurement::Source.Repair.Capability =
                if case .unavailable(let reason) = finding.repair {
                    .unavailable(.init(code: reason.code, detail: moved(reason.detail)))
                } else {
                    finding.repair
                }
            return .init(
                rule: finding.rule,
                diagnostic: .init(
                    location: .init(
                        fileID: moved(location.fileID),
                        filePath: location.filePath.map(moved),
                        line: location.line,
                        column: location.column
                    ),
                    severity: finding.diagnostic.severity,
                    identifier: finding.diagnostic.identifier,
                    message: finding.diagnostic.message
                ),
                repair: repair
            )
        }
        let verdict: Source_Measurement::Source.Measurement.Verdict =
            if case .findings(let findings) = measurement.verdict {
                .findings(findings.map(moved))
            } else {
                measurement.verdict
            }
        return .init(
            engine: measurement.engine,
            subject: subject,
            activeRules: measurement.activeRules,
            applicableRules: measurement.applicableRules,
            files: measurement.files.map(moved),
            observations: measurement.observations.map {
                .init(file: moved($0.file), rule: $0.rule, applicable: $0.applicable, coverage: $0.coverage)
            },
            suppressions: measurement.suppressions.map(moved),
            repairs: measurement.repairs.map { evidence in
                let disposition: Source_Measurement::Source.Repair.Evidence.Disposition =
                    if case .refused(let reason) = evidence.disposition {
                        .refused(.init(code: reason.code, detail: moved(reason.detail)))
                    } else {
                        evidence.disposition
                    }
                return .init(file: moved(evidence.file), rule: evidence.rule, disposition: disposition)
            },
            controls: measurement.controls,
            verdict: verdict
        )
    }

    /// The files under `prefix` that `measurement` has a finding in, relative
    /// to it.
    private static func unrepaired(
        in measurement: Source_Measurement::Source.Measurement,
        prefix: Swift.String
    ) -> Swift.Set<Swift.String> {
        guard case .findings(let findings) = measurement.verdict else { return [] }
        return Swift.Set(
            findings.compactMap { finding in
                guard let file = finding.diagnostic.location.filePath, file.hasPrefix(prefix) else { return nil }
                return Swift.String(file.dropFirst(prefix.count))
            }
        )
    }

    private static func only(
        _ measurements: [Source_Measurement::Source.Measurement]
    ) throws(Institute.Error) -> Source_Measurement::Source.Measurement {
        guard measurements.count == 1, let measurement = measurements.first else {
            throw .process("swift-format returned \(measurements.count) measurements, expected one")
        }
        return measurement
    }

    private static func text(_ reasons: [Source_Measurement::Source.Reason]) -> Swift.String {
        reasons.map { "\($0.code): \($0.detail)" }.joined(separator: "; ")
    }

    /// The files under `root`, by path relative to it, as `Source.Repair`
    /// reads and writes them.
    static func files(root: Swift.String) -> Source_Repair::Source.Repair.FileSystem {
        @Sendable func file(_ path: Swift.String) -> Result<File, Source_Measurement::Source.Reason> {
            guard !path.isEmpty, !path.hasPrefix("/"), !path.split(separator: "/").contains("..") else {
                return .failure(.init(code: "path-escape", detail: path))
            }
            do throws(File.Path.Error) {
                return .success(File(try File.Path(root) / File.Path(path)))
            } catch {
                return .failure(.init(code: "invalid-path", detail: path))
            }
        }
        @Sendable func write(_ path: Swift.String, _ contents: [Swift.UInt8]) -> Result<Void, Source_Measurement::Source.Reason> {
            switch file(path) {
            case .failure(let reason): return .failure(reason)

            case .success(let file):
                do throws(File.System.Create.Directory.Error) {
                    if let parent = file.path.parent {
                        try File.System.Create.Directory.create(at: parent, createIntermediates: true)
                    }
                } catch {
                    return .failure(.init(code: "write", detail: "\(path): \(error)"))
                }
                do throws(File.System.Write.Atomic.Error) {
                    try file.write.atomic(contentsOf: contents.map(Byte.init(_:)))
                    return .success(())
                } catch {
                    return .failure(.init(code: "write", detail: "\(path): \(error)"))
                }
            }
        }
        return .init(
            exists: { path in
                if case .success(let file) = file(path) { return file.stat.exists }
                return false
            },
            read: { path in
                switch file(path) {
                case .failure(let reason): return .failure(reason)

                case .success(let file):
                    do throws(Either<File.System.Read.Full.Error, Never>) {
                        return .success(
                            try File.System.Read.Full.read(from: file.path) { span in
                                var result: [Swift.UInt8] = []
                                result.reserveCapacity(span.count)
                                for index in span.indices { result.append(span[index].bitPattern) }
                                return result
                            }
                        )
                    } catch {
                        return .failure(.init(code: "read", detail: "\(path): \(error)"))
                    }
                }
            },
            write: write,
            move: { from, _ in .failure(.init(code: "unsupported", detail: "move \(from)")) },
            delete: { path in .failure(.init(code: "unsupported", detail: "delete \(path)")) }
        )
    }
}

extension Institute.Source.Application {
    /// Where the pinned tools are kept between packages:
    /// `$XDG_CACHE_HOME/institute/source-tools`, else
    /// `$HOME/.cache/institute/source-tools`, else `nil`, and each package
    /// keeps its own.
    public static func tools(cache: Swift.String?, home: Swift.String?) -> File.Directory? {
        do throws(File.Path.Error) {
            let kept = try File.Path("institute/source-tools")
            if let cache = absolute(cache) { return File.Directory(cache / kept) }
            if let home = absolute(home) { return File.Directory(home / (try File.Path(".cache")) / kept) }
            return nil
        } catch {
            return nil
        }
    }

    /// `text` as a path, when it is one and names its root: what the
    /// platform calls absolute, `/…` on POSIX and `C:\…` on Windows.
    private static func absolute(_ text: Swift.String?) -> File.Path? {
        guard let text else { return nil }
        do throws(File.Path.Error) {
            let path = try File.Path(text)
            return path.isAbsolute ? path : nil
        } catch {
            return nil
        }
    }
}
