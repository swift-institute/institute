import Byte
public import Institute_Model
public import Institute_Repository_Policy

import struct Swift.String

extension Institute.Repository.Policy.Command {
    static func uniformityWave(_ arguments: [Swift.String]) async throws(Error) {
        guard let operation = arguments.first else {
            throw configuration(
                "uniformity-wave requires payload, census, capacity, attest, preflight, apply, "
                    + "close, recensus, or restore"
            )
        }
        let values = try values(Array(arguments.dropFirst()))
        if operation == "payload" {
            return try payloadUniformityWave(values)
        }
        if operation == "attest" {
            return try attestUniformityWave(values)
        }
        let client = try waveClient()
        switch operation {
        case "census":
            try await censusUniformityWave(values, client: client)

        case "capacity":
            try await capacityUniformityWave(values, client: client)

        case "preflight":
            try await preflightUniformityWave(values, client: client)

        case "apply":
            try await applyUniformityWave(values, client: client)

        case "close":
            try await closeUniformityWave(values, client: client)

        case "recensus":
            try await recensusUniformityWave(values, client: client)

        case "restore":
            try await restoreUniformityWave(values, client: client)

        default:
            throw configuration(
                "uniformity-wave operation must be payload, census, capacity, attest, "
                    + "preflight, apply, close, recensus, or restore"
            )
        }
    }

    /// Writes the embedded ratified shape policy bytes, digest-verified,
    /// so every host phase consumes one canonical file whose checksum an
    /// independent verifier can compare against the ratified digest.
    private static func payloadUniformityWave(
        _ values: [Swift.String: Swift.String]
    ) throws(Error) {
        guard values.count == 1, let output = values["--output"] else {
            throw configuration("uniformity-wave payload requires only --output <path>")
        }
        let payload: [Byte]
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            payload = try Institute.Repository.Policy.Uniformity.Wave.Payload.canonical()
        } catch {
            throw .wave(error)
        }
        try write(payload, to: output)
        print(
            "institute repository: uniformity-wave payload "
                + "digest=\(Institute.Repository.Policy.Uniformity.Wave.Payload.digest)"
        )
    }

    private static func attestUniformityWave(
        _ values: [Swift.String: Swift.String]
    ) throws(Error) {
        let attestation = try attestation(values, operation: "uniformity-wave")
        try encode(attestation, to: (try value("--output", in: values)))
        print(
            "institute repository: uniformity-wave attested \(attestation.organization) "
                + "repositories=\(attestation.repositories.count) "
                + "installation=\(attestation.installationID)"
        )
    }

    private static func capacityUniformityWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        // Exactly one requirement source: an explicit fixed budget
        // (census/recensus enumeration), or a subject count the Swift
        // owner prices itself — the host never carries the formula.
        let required: Int
        switch (values["--required"], values["--subjects"]) {
        case (let requiredValue?, nil):
            guard values.count == 2, let value = Int(requiredValue), value > 0 else {
                throw configuration(
                    "uniformity-wave capacity requires --required <positive integer> "
                        + "--output <path>"
                )
            }
            required = value

        case (nil, let subjectsValue?):
            guard values.count == 2, let subjects = Int(subjectsValue), subjects > 0 else {
                throw configuration(
                    "uniformity-wave capacity requires --subjects <positive integer> "
                        + "--output <path>"
                )
            }
            required = Institute.Repository.Policy.Uniformity.Wave.Capacity.requirement(
                subjects: subjects
            )

        default:
            throw configuration(
                "uniformity-wave capacity requires exactly one of --required or --subjects"
            )
        }
        guard let output = values["--output"] else {
            throw configuration("uniformity-wave capacity requires --output <path>")
        }
        let capacity: Institute.Repository.Policy.Caller.Wave.Capacity
        do throws(Institute.Repository.Policy.Client.Error) {
            capacity = try await client.capacity(requiredRequests: required)
        } catch {
            throw .client(error)
        }
        try encode(capacity, to: output)
        guard capacity.accepted else {
            throw .wave(
                .verification(
                    "GitHub API capacity has \(capacity.remaining) requests remaining; "
                        + "\(capacity.required) are required"
                )
            )
        }
        print(
            "institute repository: uniformity-wave capacity accepted "
                + "remaining=\(capacity.remaining) "
                + "required=\(capacity.required) reset=\(capacity.resetAt)"
        )
    }

    private static func censusUniformityWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        guard values.count == 2,
            let fleetPath = values["--fleet"],
            let output = values["--output"]
        else {
            throw configuration(
                "uniformity-wave census requires --fleet <policy> --output <path>"
            )
        }
        let fleet = try fleet(at: fleetPath)
        let population: Institute.Repository.Policy.Uniformity.Wave.Population
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            population = try await Institute.Repository.Policy.Uniformity.Wave.enumerate(
                client: client,
                fleet: fleet
            )
        } catch {
            throw .wave(error)
        }
        try encode(population, to: output)
        print(
            "institute repository: uniformity-wave census examined=\(population.examined) "
                + "eligible=\(population.subjects.count) "
                + "digest=\(population.commitment.stateDigest)"
        )
    }

    private static func preflightUniformityWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        let required = [
            "--repository", "--population", "--payload", "--policy", "--integration-id",
            "--policy-digest", "--policy-source", "--attestation", "--recovery", "--receipt",
        ]
        try require(values, keys: required, operation: "uniformity-wave preflight")
        let attestationPath = try value("--attestation", in: values)
        let attestation:
            (
                attestation: Institute.Repository.Policy.Uniformity.Wave.Attestation,
                digest: Swift.String
            )
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            attestation = try Institute.Repository.Policy.Uniformity.Wave.Attestation.read(
                at: attestationPath
            )
        } catch {
            throw .wave(error)
        }
        let population: Institute.Repository.Policy.Uniformity.Wave.Population = try decode(
            at: (try value("--population", in: values)),
            label: "uniformity-wave population"
        )
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            try population.validate()
        } catch {
            throw .wave(error)
        }
        let repository = (try value("--repository", in: values))
        guard let subject = population.subjects.first(where: { $0.repository == repository }),
            population.subjects.filter({ $0.repository == repository }).count == 1
        else {
            throw configuration(
                "\(repository): not exactly one subject in committed population"
            )
        }
        let request = try uniformityWaveRequest(
            subject: subject,
            population: population.commitment,
            values: values
        )
        let result:
            (
                recovery: Institute.Repository.Policy.Uniformity.Wave.Recovery,
                receipt: Institute.Repository.Policy.Uniformity.Wave.Preflight
            )
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            result = try await Institute.Repository.Policy.Uniformity.Wave.preflight(
                client: client,
                request: request,
                attestation: attestation.attestation,
                attestationDigest: attestation.digest
            )
        } catch {
            throw .wave(error)
        }
        try encode(result.recovery, to: (try value("--recovery", in: values)))
        try encode(result.receipt, to: (try value("--receipt", in: values)))
        print(
            "institute repository: uniformity-wave preflight accepted \(repository) "
                + "recovery=\(result.receipt.recoveryDigest)"
        )
    }

    private static func applyUniformityWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        let required = ["--recovery", "--payload", "--events", "--receipt"]
        try require(values, keys: required, operation: "uniformity-wave apply")
        let recovery: Institute.Repository.Policy.Uniformity.Wave.Recovery = try decode(
            at: (try value("--recovery", in: values)),
            label: "uniformity-wave recovery"
        )
        let payload = try bytes(at: (try value("--payload", in: values)), label: "shape policy payload")
        let request = Institute.Repository.Policy.Uniformity.Wave.Request(
            repository: recovery.repository,
            expectedRepositoryID: recovery.repositoryID,
            expectedHead: recovery.rollbackHead,
            expectedManifest: recovery.manifest,
            expectedShape: recovery.shape,
            payload: payload,
            canonicalRuleset: recovery.canonicalRuleset,
            integrationID: recovery.integrationID,
            population: recovery.population,
            policyDigest: recovery.policyDigest,
            policySource: recovery.policySource,
            commitMessage: uniformityCommitMessage
        )
        let events = (try value("--events", in: values))
        let receipt: Institute.Repository.Policy.Uniformity.Wave.Receipt
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            receipt = try await Institute.Repository.Policy.Uniformity.Wave.run(
                client: client,
                request: request,
                recovery: recovery,
                record: { try append($0, to: events) }
            )
        } catch {
            throw .wave(error)
        }
        try encode(receipt, to: (try value("--receipt", in: values)))
        print(
            "institute repository: uniformity-wave \(receipt.changed ? "applied" : "converged") "
                + "\(receipt.repository) head=\(receipt.newHead) "
                + "gitignore=\(receipt.newGitignore) "
                + "deleted=\(receipt.deleted.count) bypass-closed=\(receipt.bypassClosed)"
        )
    }

    private static func closeUniformityWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        let required = ["--recovery", "--payload", "--output"]
        try require(values, keys: required, operation: "uniformity-wave close")
        let recovery: Institute.Repository.Policy.Uniformity.Wave.Recovery = try decode(
            at: (try value("--recovery", in: values)),
            label: "uniformity-wave recovery"
        )
        let payload = try bytes(at: (try value("--payload", in: values)), label: "shape policy payload")
        let closure: Institute.Repository.Policy.Uniformity.Wave.Closure
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            closure = try await Institute.Repository.Policy.Uniformity.Wave.close(
                client: client,
                recovery: recovery,
                payload: payload
            )
        } catch {
            throw .wave(error)
        }
        try encode(closure, to: (try value("--output", in: values)))
        guard closure.accepted else {
            throw .wave(
                .verification("\(closure.repository): uniformity closure was not accepted")
            )
        }
        print("institute repository: uniformity-wave closure accepted \(closure.repository)")
    }

    private static func recensusUniformityWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        let required = [
            "--fleet", "--original", "--payload", "--receipts", "--events", "--closures",
            "--policy-digest", "--policy-source", "--output",
        ]
        try require(values, keys: required, operation: "uniformity-wave recensus")
        let original: Institute.Repository.Policy.Uniformity.Wave.Population = try decode(
            at: (try value("--original", in: values)),
            label: "original uniformity-wave population"
        )
        let fleetPolicy = try fleet(at: (try value("--fleet", in: values)))
        let current: Institute.Repository.Policy.Uniformity.Wave.Population
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            current = try await Institute.Repository.Policy.Uniformity.Wave.enumerate(
                client: client,
                fleet: fleetPolicy
            )
        } catch {
            throw .wave(error)
        }
        let payload = try bytes(at: (try value("--payload", in: values)), label: "shape policy payload")
        let receipts: [Institute.Repository.Policy.Uniformity.Wave.Receipt] =
            try decodeDirectory(
                at: (try value("--receipts", in: values)),
                label: "uniformity-wave receipts"
            )
        let closures: [Institute.Repository.Policy.Uniformity.Wave.Closure] =
            try decodeDirectory(
                at: (try value("--closures", in: values)),
                label: "uniformity-wave closures"
            )
        let events: [Institute.Repository.Policy.Uniformity.Wave.Event] =
            try decodeLinesDirectory(
                at: (try value("--events", in: values)),
                label: "uniformity-wave events"
            )
        let policyDigest = try value("--policy-digest", in: values)
        let policySource = try value("--policy-source", in: values)
        let recensus: Institute.Repository.Policy.Uniformity.Wave.Recensus
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            recensus = try Institute.Repository.Policy.Uniformity.Wave.recensus(
                original: original,
                current: current,
                evidence: .init(
                    payload: payload,
                    receipts: receipts,
                    events: events,
                    closures: closures,
                    policyDigest: policyDigest,
                    policySource: policySource
                )
            )
        } catch {
            throw .wave(error)
        }
        try encode(recensus, to: (try value("--output", in: values)))
        guard recensus.accepted else {
            let mismatches = recensus.observations.filter { !$0.matches }.map(\.repository)
            throw .wave(
                .verification(
                    "uniformity recensus refused \(mismatches.count) subjects: "
                        + mismatches.joined(separator: ", ")
                )
            )
        }
        print(
            "institute repository: uniformity-wave recensus accepted "
                + "examined=\(recensus.examined) eligible=\(recensus.observations.count) "
                + "population=\(recensus.originalPopulation.subjectDigest)"
        )
    }

    private static func restoreUniformityWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        guard values.count == 1, let path = values["--recovery"] else {
            throw configuration("uniformity-wave restore requires only --recovery <path>")
        }
        let recovery: Institute.Repository.Policy.Uniformity.Wave.Recovery = try decode(
            at: path,
            label: "uniformity-wave recovery"
        )
        guard let snapshot = recovery.priorRuleset else {
            print("institute repository: uniformity-wave recovery has no prior ruleset")
            return
        }
        do throws(Institute.Repository.Policy.Uniformity.Wave.Error) {
            try await Institute.Repository.Policy.Uniformity.Wave.restore(
                client: client,
                snapshot: snapshot
            )
        } catch {
            throw .wave(error)
        }
        print("institute repository: uniformity-wave restored \(recovery.repository)")
    }

    private static func uniformityWaveRequest(
        subject: Institute.Repository.Policy.Uniformity.Wave.Subject,
        population: Institute.Repository.Policy.Uniformity.Wave.Commitment,
        values: [Swift.String: Swift.String]
    ) throws(Error) -> Institute.Repository.Policy.Uniformity.Wave.Request {
        guard let integrationID = Int64((try value("--integration-id", in: values))), integrationID > 0 else {
            throw configuration("uniformity-wave --integration-id must be a positive integer")
        }
        let policyDigest = (try value("--policy-digest", in: values))
        let policySource = (try value("--policy-source", in: values))
        guard policyDigest.count == 64, policySource.count == 40 else {
            throw configuration("uniformity-wave policy digest or source is not exact")
        }
        return .init(
            repository: subject.repository,
            expectedRepositoryID: subject.repositoryID,
            expectedHead: subject.head,
            expectedManifest: subject.manifest,
            expectedShape: subject.shape,
            payload: try bytes(at: (try value("--payload", in: values)), label: "shape policy payload"),
            canonicalRuleset: try canonicalRuleset(at: (try value("--policy", in: values))),
            integrationID: integrationID,
            population: population,
            policyDigest: policyDigest,
            policySource: policySource,
            commitMessage: uniformityCommitMessage
        )
    }

    /// The ratified transaction commit message. The `[skip ci]` suffix is
    /// mandatory: it is how the caller wave avoided 469 post-main
    /// matrices, and this wave rides the same discipline.
    private static var uniformityCommitMessage: Swift.String {
        "Adopt the canonical package shape policy [skip ci]"
    }
}
