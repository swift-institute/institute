import Byte
import Foundation
public import Institute_Model
import Institute_Repository_Application
import Institute_Repository_Policy

actor CallerWaveMockClient: Institute.Repository.Policy.Caller.Wave.Client {
    var remainingRequests = 5_000
    var repository = Institute.Repository.Policy.Caller.Wave.Repository(
        id: 1,
        visibility: "public",
        archived: false,
        disabled: false,
        defaultBranch: "main"
    )
    var currentHead = "old-head"
    var oldCaller = [Byte](utf8: "old\n")
    var newCaller = [Byte](utf8: "new\n")
    var oldBlob = "old-blob"
    var newBlob = "new-blob"
    var rulesetData: [Byte]
    var rulesetID: Int64?
    var replacementCount = 0
    var creationCount = 0
    var moveFailure = false
    var restorationFailure = false
    var convergenceFailure = false
    var persistentConvergenceFailure = false
    var moveHeadOnOpen = false
    var openingResponseLost = false
    var closingResponseLost = false
    var commitFailure = false
    var rulesetReadFailures = 0
    var readFailureAfterOpening = false
    var moveHeadAfterManifestRead = false
    var staleHeadReadsAfterMove = 0
    var staleHead: String?
    var pausedAttempts: [Int] = []
    let emptyRepositories: Bool
    let callerAbsent: Bool
    let privateOrganizations: Set<String>

    init(
        ruleset: [Byte],
        emptyRepositories: Bool = false,
        callerAbsent: Bool = false,
        rulesetAbsent: Bool = false,
        privateOrganizations: Set<String> = []
    ) {
        rulesetData = ruleset
        rulesetID = rulesetAbsent ? nil : 7
        self.emptyRepositories = emptyRepositories
        self.callerAbsent = callerAbsent
        self.privateOrganizations = privateOrganizations
    }

    func capacity(
        requiredRequests: Int
    ) async throws(Institute.Repository.Policy.Client.Error)
        -> Institute.Repository.Policy.Caller.Wave.Capacity
    {
        .init(remaining: remainingRequests, required: requiredRequests, resetAt: 1_787_000_000)
    }

    func waveRepositories(
        organization: String
    ) async throws(Institute.Repository.Policy.Client.Error)
        -> Institute.Repository.Policy.Caller.Wave.Listing
    {
        if emptyRepositories { return .init(repositories: [], expected: 0) }
        return .init(
            repositories: [
                .init(
                    id: 1,
                    name: "example",
                    fullName: "\(organization)/example",
                    visibility: privateOrganizations.contains(organization)
                        ? "private" : "public",
                    archived: false,
                    disabled: false,
                    fork: false,
                    size: 1
                )
            ],
            expected: 1
        )
    }

    func rootManifest(
        _: String,
        head _: String
    ) async throws(Institute.Repository.Policy.Client.Error)
        -> Institute.Repository.Policy.Caller.Wave.Manifest?
    {
        if moveHeadAfterManifestRead {
            moveHeadAfterManifestRead = false
            currentHead = "moved-during-manifest-read"
        }
        return .init(kind: "file", blob: "manifest-blob")
    }

    func waveRepository(
        _: String
    ) async throws(Institute.Repository.Policy.Client.Error)
        -> Institute.Repository.Policy.Caller.Wave.Repository
    {
        repository
    }

    func head(_: String) async throws(Institute.Repository.Policy.Client.Error) -> String {
        if staleHeadReadsAfterMove > 0, let staleHead {
            staleHeadReadsAfterMove -= 1
            return staleHead
        }
        return currentHead
    }

    func callerSource(
        _: String,
        head: String
    ) async throws(Institute.Repository.Policy.Client.Error)
        -> Institute.Repository.Policy.Caller.Wave.CallerSource
    {
        head == "new-head"
            ? .init(blob: newBlob, bytes: newCaller)
            : .init(blob: oldBlob, bytes: oldCaller)
    }

    func callerSourceIfPresent(
        _ repository: String,
        head: String
    ) async throws(Institute.Repository.Policy.Client.Error)
        -> Institute.Repository.Policy.Caller.Wave.CallerSource?
    {
        if callerAbsent { return nil }
        return try await callerSource(repository, head: head)
    }

    func rulesets(
        _: String
    ) async throws(Institute.Repository.Policy.Client.Error)
        -> [Institute.Repository.Policy.Caller.Wave.RulesetReference]
    {
        rulesetID.map { [.init(id: $0, name: "Institute protected main")] } ?? []
    }

    func ruleset(
        _: String,
        id _: Int64
    ) async throws(Institute.Repository.Policy.Client.Error) -> [Byte] {
        if rulesetReadFailures > 0 {
            rulesetReadFailures -= 1
            throw .transport(path: "ruleset", message: "injected read failure")
        }
        return rulesetData
    }

    func replaceRuleset(
        _: String,
        id _: Int64,
        payload: [Byte]
    ) async throws(Institute.Repository.Policy.Client.Error) {
        let object = try? JSONSerialization.jsonObject(with: Data(payload.map { $0.underlying })) as? [String: Any]
        let bypass = object?["bypass_actors"] as? [Any] ?? []
        let prior = try? JSONSerialization.jsonObject(with: Data(rulesetData.map { $0.underlying })) as? [String: Any]
        let priorBypass = prior?["bypass_actors"] as? [Any] ?? []
        if bypass.isEmpty, convergenceFailure {
            if !persistentConvergenceFailure { convergenceFailure = false }
            throw .precondition("convergence failed")
        }
        if bypass.isEmpty, restorationFailure {
            throw .precondition("restore failed")
        }
        if !bypass.isEmpty, moveHeadOnOpen {
            currentHead = "concurrent-head"
        }
        rulesetData = payload
        replacementCount += 1
        if !bypass.isEmpty, readFailureAfterOpening {
            readFailureAfterOpening = false
            rulesetReadFailures = 1
        }
        if !bypass.isEmpty, openingResponseLost {
            openingResponseLost = false
            throw .transport(path: "ruleset", message: "opening response lost")
        }
        if bypass.isEmpty, !priorBypass.isEmpty, closingResponseLost {
            closingResponseLost = false
            throw .transport(path: "ruleset", message: "closing response lost")
        }
    }

    func createRuleset(
        _: String,
        payload: [Byte]
    ) async throws(Institute.Repository.Policy.Client.Error) -> Int64 {
        guard rulesetID == nil else {
            throw .precondition("ruleset already exists")
        }
        rulesetID = 7
        rulesetData = payload
        creationCount += 1
        return 7
    }

    func createBlob(
        _: String,
        content: [Byte]
    ) async throws(Institute.Repository.Policy.Client.Error) -> String {
        newCaller = content
        return newBlob
    }

    func createCommit(
        _: String,
        parent _: String,
        blob _: String,
        message _: String
    ) async throws(Institute.Repository.Policy.Client.Error) -> String {
        if commitFailure {
            throw .transport(path: "commit", message: "injected process interruption")
        }
        return "new-head"
    }

    func moveMain(
        _: String,
        to head: String
    ) async throws(Institute.Repository.Policy.Client.Error) {
        if moveFailure {
            throw .precondition("move failed")
        }
        // Read-after-write staleness: the move itself succeeds, but the
        // next `staleHeadReadsAfterMove` head reads serve the previous
        // value, the way a lagging replica would.
        if staleHeadReadsAfterMove > 0 { staleHead = currentHead }
        currentHead = head
    }

    func pause(attempt: Int) async {
        pausedAttempts.append(attempt)
    }

    func setStaleHeadReadsAfterMove(_ count: Int) {
        staleHeadReadsAfterMove = count
    }

    func pauses() -> [Int] {
        pausedAttempts
    }

    func setHead(_ value: String) {
        currentHead = value
    }

    func setMoveHeadAfterManifestRead() {
        moveHeadAfterManifestRead = true
    }

    func setBlob(_ value: String) {
        oldBlob = value
    }

    func setCaller(bytes: [Byte], blob: String) {
        oldCaller = bytes
        oldBlob = blob
    }

    func setMoveFailure() {
        moveFailure = true
    }

    func setRestorationFailure() {
        restorationFailure = true
    }

    func setConvergenceFailure(persistent: Bool = false) {
        convergenceFailure = true
        persistentConvergenceFailure = persistent
    }

    func setMoveHeadOnOpen() {
        moveHeadOnOpen = true
    }

    func setOpeningResponseLost() {
        openingResponseLost = true
    }

    func setClosingResponseLost() {
        closingResponseLost = true
    }

    func setCommitFailure() {
        commitFailure = true
    }

    func setRulesetReadFailures(_ count: Int) {
        rulesetReadFailures = count
    }

    func setReadFailureAfterOpening() {
        readFailureAfterOpening = true
    }

    func openBypass(integrationID: Int64) throws {
        guard var object = try JSONSerialization.jsonObject(with: Data(rulesetData.map { $0.underlying })) as? [String: Any]
        else {
            throw Institute.Repository.Policy.Client.Error.precondition("ruleset is not an object")
        }
        object["bypass_actors"] = [
            [
                "actor_id": integrationID,
                "actor_type": "Integration",
                "bypass_mode": "always",
            ]
        ]
        rulesetData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).map { Byte(bitPattern: $0) }
    }

    func bypassOpen(integrationID: Int64) -> Bool {
        Institute.Repository.Policy.Caller.Wave.RulesetSnapshot.containsIntegration(
            rulesetData,
            integrationID: integrationID
        )
    }

    func replacements() -> Int {
        replacementCount
    }

    func creations() -> Int {
        creationCount
    }
}
