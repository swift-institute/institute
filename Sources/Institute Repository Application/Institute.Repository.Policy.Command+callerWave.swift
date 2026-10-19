import Byte
import Calendar_Gregorian
import Environment
import GitHub_App
public import Institute_Model
public import Institute_Repository_Policy
import RFC_3339
import Time

import struct Swift.String

extension Institute.Repository.Policy.Command {
    static func callerWave(_ arguments: [Swift.String]) async throws(Error) {
        guard let operation = arguments.first else {
            throw configuration(
                "caller-wave requires census, capacity, attest, preflight, apply, close, "
                    + "recensus, or restore"
            )
        }
        let values = try values(Array(arguments.dropFirst()))
        if operation == "attest" {
            return try attestCallerWave(values)
        }
        let client = try waveClient()
        switch operation {
        case "census":
            try await censusCallerWave(values, client: client)

        case "capacity":
            try await capacityCallerWave(values, client: client)

        case "preflight":
            try await preflightCallerWave(values, client: client)

        case "apply":
            try await applyCallerWave(values, client: client)

        case "close":
            try await closeCallerWave(values, client: client)

        case "recensus":
            try await recensusCallerWave(values, client: client)

        case "restore":
            try await restoreCallerWave(values, client: client)

        default:
            throw configuration(
                "caller-wave operation must be census, capacity, attest, preflight, apply, "
                    + "close, recensus, or restore"
            )
        }
    }

    /// The Process-based `gh` transport carries the credential itself;
    /// the guard preserves the workflow contract that a wave phase never
    /// starts without one.
    static func waveClient() throws(Error) -> Client {
        guard let token: Swift.String = Environment.read("GH_TOKEN"), !token.isEmpty else {
            throw configuration("GH_TOKEN is required")
        }
        return Client()
    }

    /// Now in UTC, `YYYY-MM-DDTHH:MM:SSZ` — the issuance stamp recorded
    /// on wave attestations.
    static var issuedAt: Swift.String {
        Gregorian.DateTime(Time.Instant(secondsSinceUnixEpoch: GitHub.App.Clock.now()))
            .rfc3339.format(offset: .utc, precision: 0)
    }

    static func attestation(
        _ values: [Swift.String: Swift.String],
        operation: Swift.String
    ) throws(Error) -> Institute.Repository.Policy.Caller.Wave.Attestation {
        let required = [
            "--organization", "--app-client-id", "--app-slug", "--installation-id",
            "--repositories", "--permissions", "--run-id", "--output",
        ]
        try require(values, keys: required, operation: "\(operation) attest")
        guard let installationID = Int64((try value("--installation-id", in: values))), installationID > 0 else {
            throw configuration("\(operation) --installation-id must be a positive integer")
        }
        guard let runID = Int64((try value("--run-id", in: values))), runID > 0 else {
            throw configuration("\(operation) --run-id must be a positive integer")
        }
        let organization = (try value("--organization", in: values))
        let appClientID = (try value("--app-client-id", in: values))
        let appSlug = (try value("--app-slug", in: values))
        guard !organization.isEmpty, !appClientID.isEmpty, !appSlug.isEmpty else {
            throw configuration("\(operation) attest identity values must be nonempty")
        }
        let repositories = (try value("--repositories", in: values)).split(separator: ",").map(Swift.String.init)
        guard !repositories.isEmpty else {
            throw configuration("\(operation) attest --repositories must be nonempty")
        }
        var permissions: [Swift.String: Swift.String] = [:]
        for entry in (try value("--permissions", in: values)).split(separator: ",") {
            let pair = entry.split(separator: "=", omittingEmptySubsequences: false)
            guard pair.count == 2, !pair[0].isEmpty, !pair[1].isEmpty,
                permissions.updateValue(
                    Swift.String(pair[1]),
                    forKey: Swift.String(pair[0])
                ) == nil
            else {
                throw configuration(
                    "\(operation) attest --permissions must be unique permission=grant pairs"
                )
            }
        }
        guard !permissions.isEmpty else {
            throw configuration("\(operation) attest --permissions must be nonempty")
        }
        return .init(
            appClientID: appClientID,
            appSlug: appSlug,
            installationID: installationID,
            organization: organization,
            repositories: repositories,
            permissions: permissions,
            runID: runID,
            issuedAt: issuedAt
        )
    }

    private static func attestCallerWave(
        _ values: [Swift.String: Swift.String]
    ) throws(Error) {
        let attestation = try attestation(values, operation: "caller-wave")
        try encode(attestation, to: (try value("--output", in: values)))
        print(
            "institute repository: caller-wave attested \(attestation.organization) "
                + "repositories=\(attestation.repositories.count) "
                + "installation=\(attestation.installationID)"
        )
    }

    private static func capacityCallerWave(
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
                    "caller-wave capacity requires --required <positive integer> --output <path>"
                )
            }
            required = value

        case (nil, let subjectsValue?):
            guard values.count == 2, let subjects = Int(subjectsValue), subjects > 0 else {
                throw configuration(
                    "caller-wave capacity requires --subjects <positive integer> --output <path>"
                )
            }
            required = Institute.Repository.Policy.Caller.Wave.Capacity.requirement(
                subjects: subjects
            )

        default:
            throw configuration(
                "caller-wave capacity requires exactly one of --required or --subjects"
            )
        }
        guard let output = values["--output"] else {
            throw configuration("caller-wave capacity requires --output <path>")
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
            "institute repository: caller-wave capacity accepted remaining=\(capacity.remaining) "
                + "required=\(capacity.required) reset=\(capacity.resetAt)"
        )
    }

    private static func censusCallerWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        guard values.count == 2,
            let fleetPath = values["--fleet"],
            let output = values["--output"]
        else {
            throw configuration("caller-wave census requires --fleet <policy> --output <path>")
        }
        let fleet = try fleet(at: fleetPath)
        let population: Institute.Repository.Policy.Caller.Wave.Population
        do throws(Institute.Repository.Policy.Caller.Wave.Error) {
            population = try await Institute.Repository.Policy.Caller.Wave.enumerate(
                client: client,
                fleet: fleet
            )
        } catch {
            throw .wave(error)
        }
        try encode(population, to: output)
        print(
            "institute repository: caller-wave census examined=\(population.examined) "
                + "eligible=\(population.subjects.count) "
                + "digest=\(population.commitment.stateDigest)"
        )
    }

    private static func preflightCallerWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        let required = [
            "--repository", "--population", "--caller", "--policy", "--integration-id",
            "--policy-digest", "--policy-source", "--attestation", "--recovery", "--receipt",
        ]
        try require(values, keys: required, operation: "caller-wave preflight")
        let attestationPath = try value("--attestation", in: values)
        let attestation:
            (
                attestation: Institute.Repository.Policy.Caller.Wave.Attestation,
                digest: Swift.String
            )
        do throws(Institute.Repository.Policy.Caller.Wave.Error) {
            attestation = try Institute.Repository.Policy.Caller.Wave.Attestation.read(
                at: attestationPath
            )
        } catch {
            throw .wave(error)
        }
        let population: Institute.Repository.Policy.Caller.Wave.Population = try decode(
            at: (try value("--population", in: values)),
            label: "caller-wave population"
        )
        do throws(Institute.Repository.Policy.Caller.Wave.Error) {
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
        let request = try callerWaveRequest(
            subject: subject,
            population: population.commitment,
            values: values
        )
        let result:
            (
                recovery: Institute.Repository.Policy.Caller.Wave.Recovery,
                receipt: Institute.Repository.Policy.Caller.Wave.Preflight
            )
        do throws(Institute.Repository.Policy.Caller.Wave.Error) {
            result = try await Institute.Repository.Policy.Caller.Wave.preflight(
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
            "institute repository: caller-wave preflight accepted \(repository) "
                + "recovery=\(result.receipt.recoveryDigest)"
        )
    }

    private static func applyCallerWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        let required = ["--recovery", "--caller", "--events", "--receipt"]
        try require(values, keys: required, operation: "caller-wave apply")
        let recovery: Institute.Repository.Policy.Caller.Wave.Recovery = try decode(
            at: (try value("--recovery", in: values)),
            label: "caller-wave recovery"
        )
        let caller = try bytes(at: (try value("--caller", in: values)), label: "terminal caller")
        let request = Institute.Repository.Policy.Caller.Wave.Request(
            repository: recovery.repository,
            expectedRepositoryID: recovery.repositoryID,
            expectedHead: recovery.rollbackHead,
            expectedManifest: recovery.manifest,
            expectedBlob: recovery.caller.blob,
            caller: caller,
            canonicalRuleset: recovery.canonicalRuleset,
            integrationID: recovery.integrationID,
            population: recovery.population,
            policyDigest: recovery.policyDigest,
            policySource: recovery.policySource,
            commitMessage: terminalCallerCommitMessage
        )
        let events = (try value("--events", in: values))
        let receipt: Institute.Repository.Policy.Caller.Wave.Receipt
        do throws(Institute.Repository.Policy.Caller.Wave.Error) {
            receipt = try await Institute.Repository.Policy.Caller.Wave.run(
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
            "institute repository: caller-wave \(receipt.changed ? "applied" : "converged") "
                + "\(receipt.repository) head=\(receipt.newHead) blob=\(receipt.newBlob) "
                + "bypass-closed=\(receipt.bypassClosed)"
        )
    }

    private static func closeCallerWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        let required = ["--recovery", "--caller", "--output"]
        try require(values, keys: required, operation: "caller-wave close")
        let recovery: Institute.Repository.Policy.Caller.Wave.Recovery = try decode(
            at: (try value("--recovery", in: values)),
            label: "caller-wave recovery"
        )
        let caller = try bytes(at: (try value("--caller", in: values)), label: "terminal caller")
        let closure: Institute.Repository.Policy.Caller.Wave.Closure
        do throws(Institute.Repository.Policy.Caller.Wave.Error) {
            closure = try await Institute.Repository.Policy.Caller.Wave.close(
                client: client,
                recovery: recovery,
                caller: caller
            )
        } catch {
            throw .wave(error)
        }
        try encode(closure, to: (try value("--output", in: values)))
        guard closure.accepted else {
            throw .wave(.verification("\(closure.repository): terminal closure was not accepted"))
        }
        print("institute repository: caller-wave closure accepted \(closure.repository)")
    }

    private static func recensusCallerWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        let required = [
            "--fleet", "--original", "--caller", "--receipts", "--events", "--closures",
            "--policy-digest", "--policy-source", "--output",
        ]
        try require(values, keys: required, operation: "caller-wave recensus")
        let original: Institute.Repository.Policy.Caller.Wave.Population = try decode(
            at: (try value("--original", in: values)),
            label: "original caller-wave population"
        )
        let fleetPolicy = try fleet(at: (try value("--fleet", in: values)))
        let current: Institute.Repository.Policy.Caller.Wave.Population
        do throws(Institute.Repository.Policy.Caller.Wave.Error) {
            current = try await Institute.Repository.Policy.Caller.Wave.enumerate(
                client: client,
                fleet: fleetPolicy
            )
        } catch {
            throw .wave(error)
        }
        let caller = try bytes(at: (try value("--caller", in: values)), label: "terminal caller")
        let receipts: [Institute.Repository.Policy.Caller.Wave.Receipt] = try decodeDirectory(
            at: (try value("--receipts", in: values)),
            label: "caller-wave receipts"
        )
        let closures: [Institute.Repository.Policy.Caller.Wave.Closure] = try decodeDirectory(
            at: (try value("--closures", in: values)),
            label: "caller-wave closures"
        )
        let events: [Institute.Repository.Policy.Caller.Wave.Event] = try decodeLinesDirectory(
            at: (try value("--events", in: values)),
            label: "caller-wave events"
        )
        let policyDigest = try value("--policy-digest", in: values)
        let policySource = try value("--policy-source", in: values)
        let recensus: Institute.Repository.Policy.Caller.Wave.Recensus
        do throws(Institute.Repository.Policy.Caller.Wave.Error) {
            recensus = try Institute.Repository.Policy.Caller.Wave.recensus(
                original: original,
                current: current,
                evidence: .init(
                    caller: caller,
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
                    "terminal recensus refused \(mismatches.count) subjects: "
                        + mismatches.joined(separator: ", ")
                )
            )
        }
        print(
            "institute repository: caller-wave recensus accepted "
                + "examined=\(recensus.examined) eligible=\(recensus.observations.count) "
                + "population=\(recensus.originalPopulation.subjectDigest)"
        )
    }

    private static func restoreCallerWave(
        _ values: [Swift.String: Swift.String],
        client: Client
    ) async throws(Error) {
        guard values.count == 1, let path = values["--recovery"] else {
            throw configuration("caller-wave restore requires only --recovery <path>")
        }
        let recovery: Institute.Repository.Policy.Caller.Wave.Recovery = try decode(
            at: path,
            label: "caller-wave recovery"
        )
        guard let snapshot = recovery.priorRuleset else {
            print("institute repository: caller-wave recovery has no prior ruleset")
            return
        }
        do throws(Institute.Repository.Policy.Caller.Wave.Error) {
            try await Institute.Repository.Policy.Caller.Wave.restore(
                client: client,
                snapshot: snapshot
            )
        } catch {
            throw .wave(error)
        }
        print("institute repository: caller-wave restored \(recovery.repository)")
    }

    private static func callerWaveRequest(
        subject: Institute.Repository.Policy.Caller.Wave.Subject,
        population: Institute.Repository.Policy.Caller.Wave.Commitment,
        values: [Swift.String: Swift.String]
    ) throws(Error) -> Institute.Repository.Policy.Caller.Wave.Request {
        guard let integrationID = Int64((try value("--integration-id", in: values))), integrationID > 0 else {
            throw configuration("caller-wave --integration-id must be a positive integer")
        }
        let policyDigest = (try value("--policy-digest", in: values))
        let policySource = (try value("--policy-source", in: values))
        guard policyDigest.count == 64, policySource.count == 40 else {
            throw configuration("caller-wave policy digest or source is not exact")
        }
        return .init(
            repository: subject.repository,
            expectedRepositoryID: subject.repositoryID,
            expectedHead: subject.head,
            expectedManifest: subject.manifest,
            expectedBlob: subject.caller.blob,
            caller: try bytes(at: (try value("--caller", in: values)), label: "terminal caller"),
            canonicalRuleset: try canonicalRuleset(at: (try value("--policy", in: values))),
            integrationID: integrationID,
            population: population,
            policyDigest: policyDigest,
            policySource: policySource,
            commitMessage: terminalCallerCommitMessage
        )
    }

    static func canonicalRuleset(at path: Swift.String) throws(Error) -> [Byte] {
        let bytes = try bytes(at: path, label: "protected-main ruleset policy")
        do throws(Institute.Repository.Policy.Ruleset.Error) {
            return try Institute.Repository.Policy.Ruleset.protectedMainPayload(from: bytes)
        } catch {
            throw .ruleset(error)
        }
    }

    private static var terminalCallerCommitMessage: Swift.String {
        """
        Adopt the terminal package CI caller [skip ci]

        Refs swift-institute/institute-continuous-integration#35
        """
    }

    static func fleet(at path: Swift.String) throws(Error) -> Institute.Repository.Policy.Fleet {
        do throws(Institute.Repository.Policy.Fleet.Error) {
            return try Institute.Repository.Policy.Fleet.read(at: path)
        } catch {
            throw .io("could not read the wave fleet policy at \(path): \(error)")
        }
    }
}
