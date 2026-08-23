public import Institute_Model
public import Foundation

extension Institute.Repository.Policy.Caller.Wave {
    public protocol Client: Sendable {
        func capacity(
            requiredRequests: Int
        ) async throws(Institute.Repository.Policy.Client.Error) -> Capacity
        func waveRepositories(
            organization: String
        ) async throws(Institute.Repository.Policy.Client.Error) -> Listing
        func rootManifest(
            _ repository: String,
            head: String
        ) async throws(Institute.Repository.Policy.Client.Error) -> Manifest?
        func waveRepository(
            _ name: String
        ) async throws(Institute.Repository.Policy.Client.Error)
            -> Repository
        func head(_ repository: String) async throws(Institute.Repository.Policy.Client.Error) -> String
        func callerSource(
            _ repository: String,
            head: String
        ) async throws(Institute.Repository.Policy.Client.Error) -> CallerSource
        func callerSourceIfPresent(
            _ repository: String,
            head: String
        ) async throws(Institute.Repository.Policy.Client.Error) -> CallerSource?
        func rulesets(
            _ repository: String
        ) async throws(Institute.Repository.Policy.Client.Error) -> [RulesetReference]
        func ruleset(
            _ repository: String,
            id: Int64
        ) async throws(Institute.Repository.Policy.Client.Error) -> Data
        func replaceRuleset(
            _ repository: String,
            id: Int64,
            payload: Data
        ) async throws(Institute.Repository.Policy.Client.Error)
        func createRuleset(
            _ repository: String,
            payload: Data
        ) async throws(Institute.Repository.Policy.Client.Error) -> Int64
        func createBlob(
            _ repository: String,
            content: Data
        ) async throws(Institute.Repository.Policy.Client.Error) -> String
        func createCommit(
            _ repository: String,
            parent: String,
            blob: String,
            message: String
        ) async throws(Institute.Repository.Policy.Client.Error) -> String
        func moveMain(
            _ repository: String,
            to head: String
        ) async throws(Institute.Repository.Policy.Client.Error)
        func pause(attempt: Int) async
    }
}
