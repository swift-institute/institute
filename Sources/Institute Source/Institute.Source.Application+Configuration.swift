internal import Byte_Primitives
public import File_System
public import Institute_Continuous_Integration_Source
internal import JSON
public import Source_Measurement

extension Institute.Source.Application {
    static func configuration(
        policy: ContinuousIntegration.Source.Policy,
        preparation: Institute.Source.Preparation
    ) throws(Institute.Error) -> (
        subject: Source.Subject,
        evidence: [Source.Artifact.Evidence]
    ) {
        let directory: File.Directory
        do throws(File.Path.Error) {
            directory = File.Directory(try .init(preparation.directory))
        } catch { throw .configuration("invalid source preparation directory") }
        let declared: [(artifact: ContinuousIntegration.Source.Artifact, path: Swift.String)] =
            [
                (policy.swiftFormat, policy.swiftFormat.path)
            ]
            + policy.bundles.map { bundle in
                let artifact = policy.linter(
                    bundle: bundle,
                    rules: Institute.Source.Profile(policy: policy).rules(for: bundle)
                )
                return (
                    artifact,
                    "\(bundle.token)-\(artifact.path)"
                )
            }
        var artifacts: [Source.Artifact] = []
        var evidence: [Source.Artifact.Evidence] = []
        for entry in declared {
            let declaration = entry.artifact
            let path = entry.path
            let file = directory[file: path]
            let actual: Source.Profile.Digest
            let readReason: Source.Reason?
            do throws(Institute.Error) {
                actual = try Self.digest(file: file.path.description)
                readReason = nil
            } catch {
                actual = .init("unreadable")
                readReason = .init(code: "configuration-read", detail: "\(error)")
            }
            let artifact = Source.Artifact(
                path: path,
                kind: .configuration,
                provenance: .generated(
                    .init(
                        owner: .init("control:continuous-integration"),
                        input: "ContinuousIntegration.Source.Policy",
                        revision: policy.revision,
                        digest: declaration.digest.hex
                    )
                ),
                digest: .init(actual.hex)
            )
            let schema = Self.schema(file: file, expected: declaration.schema)
            let expected = Source.Artifact.Identity(
                digest: .init(declaration.digest.hex),
                schema: .init(declaration.schema)
            )
            let measured = Source.Artifact.Identity(
                digest: .init(actual.hex),
                schema: .init(schema.token)
            )
            let verdict: Source.Artifact.Verdict
            if let reason = readReason ?? schema.reason {
                verdict = .unmeasured([reason])
            } else if measured == expected {
                verdict = .clean
            } else {
                verdict = .findings([
                    .init(code: "configuration-identity", detail: path)
                ])
            }
            artifacts.append(artifact)
            evidence.append(
                .init(
                    subject: "control:source-profile",
                    artifact: artifact,
                    predicate: policy.configuration.predicate,
                    actual: measured,
                    expected: expected,
                    verdict: verdict
                )
            )
        }
        return (
            subject: .init(
                identity: "control:source-profile",
                root: preparation.directory,
                artifacts: artifacts
            ),
            evidence: evidence
        )
    }

    private static func schema(
        file: File,
        expected: Swift.String
    ) -> (token: Swift.String, reason: Source.Reason?) {
        let contents: Swift.String
        do throws(Either<File.System.Read.Full.Error, Never>) {
            contents = try file.read.full { bytes in
                var storage: [Byte] = []
                storage.reserveCapacity(bytes.count)
                for index in bytes.indices { storage.append(bytes[index]) }
                return Swift.String(decoding: storage, as: Swift.UTF8.self)
            }
        } catch {
            return ("unreadable", .init(code: "configuration-read", detail: file.description))
        }
        let document: JSON
        do throws(JSON.Error) { document = try JSON.parse(contents) } catch {
            return ("malformed", .init(code: "configuration-schema", detail: "\(error)"))
        }
        guard let object = document.dictionary else {
            return ("malformed", .init(code: "configuration-schema", detail: file.description))
        }
        let prefix: Swift.String
        let key: Swift.String
        if expected.hasPrefix("swift-format:") {
            prefix = "swift-format:"
            key = "version"
        } else {
            prefix = "swift-linter-profile:"
            key = "schema"
        }
        guard let value = object[key] else {
            return ("malformed", .init(code: "configuration-schema", detail: file.description))
        }
        let version: Swift.Int
        do throws(JSON.Error) { version = try Swift.Int(json: value) } catch {
            return ("malformed", .init(code: "configuration-schema", detail: "\(error)"))
        }
        return (prefix + version.description, nil)
    }
}
